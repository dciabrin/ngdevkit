;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024 Damien Ciabrini
;;; This file is part of ngdevkit
;;;
;;; ngdevkit is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU Lesser General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;; License, or (at your option) any later version.
;;;
;;; ngdevkit is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU Lesser General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General Public License
;;; along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

;;; Slide effect, common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"

        .lclequ UPMOST_NOTE,((8*12)-1)

        .area  CODE


;;; Setup the fixed-point increment for the slide
;;; ------
;;;    c  : increment size (increment = 1/2^c)
;;;    e  : speed (increments)
;;; bc, de modified
slide_init_increment::

        ;; de: inc16 = speed / 2^c
        ld      d, e
        ld      e, #0
__slide_divide:
        srl     d
        rr      e
        dec     c
        jr      nz, __slide_divide

        ;; store absolute speed (no direction)
        ld      SLIDE_INC16(ix), e
        ld      SLIDE_INC16+1(ix), d

        ret


;;; Initialize the source note for the slide
;;; ------
;;;   ix  : state for channel
;;;    b  : current note
;;; TODO: we might get rid of this call we merge the
;;;       FX pos16 and the current channel pos.
slide_init_source::
        ;; init slide position if no slide FX is ongoing
        bit     BIT_FX_SLIDE, FX(ix)
        jr      nz, _post_init_slide
        ld      SLIDE_POS16(ix), #0
        ld      SLIDE_POS16+1(ix), b
_post_init_slide:
        ret


;;; Initialize a target note for the slide
;;; ------
;;;   ix  : state for channel
;;;    b  : current note
;;;    d  : target offset (signed)
slide_init_target::
        ;; init slide direction
        res     BIT_SLIDE_DIRECTION, SLIDE_CFG(ix)

        ;; slide target is the current position + new displacement
        ;; a: target note
        ld      a, b
        add     d
        ;; down: we also need to go one seminote below, to account
        ;; for the fractional parts of the slide.
        bit     7, d
        jr      z, _post_neg_slide
        set     BIT_SLIDE_DIRECTION, SLIDE_CFG(ix)
        dec     a
_post_neg_slide:
        ld      SLIDE_END(ix), a

        ret


;;; Increment current fixed point displacement and
;;; stop effects when the target displacement is reached
;;; ------
;;; IN:
;;;   ix : state for channel
;;;   hl : offset of current note for channel
;;; OUT:
;;;    a : whether effect is finished (0: finished, 1: still running)
;;;    d : when effect is finished, target displacement
;;; bc, de, hl modified
eval_slide_step:
        ;; de: decimal note address (TODO get rid of it)
        push    ix
        pop     de
        add     hl, de
        ex      de, hl

        ;; bc: increment
        ld      c, SLIDE_INC16(ix)
        ld      b, SLIDE_INC16+1(ix)
        ;; hl: decimal note (FX copy)
        ld      l, SLIDE_POS16(ix)
        ld      h, SLIDE_POS16+1(ix)

        ;; c: 0 slide up, 1 slide down
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(ix)
        jr      nz, _slide_sub_inc

_slide_add_inc:
        add     hl, bc
        ld      b, SLIDE_END(ix)
        ld      a, h
        jr      _slide_cp
_slide_sub_inc:
        or      a
        sbc     hl, bc
        ld      b, h
        ld      a, SLIDE_END(ix)

        ;; c: effect is still running (default)
        ld      c, #1

        ;; have we reached the end of the slide?
        ;; slide up:   continue if cur < end
        ;; slide down: continue if end < cur
        ;; note: we don't check for equality because the increment
        ;; can go past the target note
_slide_cp:
        cp      b
        jp      m, _slide_intermediate

        ;; slide is finished, stop effect and clamp output
        res     BIT_FX_SLIDE, FX(ix)
        xor     a
        ld      SLIDE_POS16(ix), a
        ld      SLIDE_POS16+1(ix), a

        ;; hl: clamp the last slide pos to the target displacement
        ld      h, SLIDE_END(ix)
        ld      l, #0

        ;; for slide down, we finish one note below the real target to play
        ;; all ticks with fractional parts. Adjust the end displacement back if needed
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(ix)
        jr      z, _slide_post_sub_clamp
        inc     h
_slide_post_sub_clamp:
        ld      c, #0

_slide_intermediate:
        ;; effect is still running
        ;; TODO: if we stop the slide at this point, we can only keep the
        ;; integer part of the note, which is likely not matching Furnace's semantics
        ld      SLIDE_POS16(ix), l
        ld      SLIDE_POS16+1(ix), h
        ld      a, h
        ld      (de), a

        ;; running status
        ld      a, c

        ret


;;; Check whether the slide NSS opcode should disable the current slide FX
;;; ------
;;; IN:
;;;   ix  : state for channel
;;; [ hl ]: FX args in the NSS stream
;;; OUT:
;;;   carry: 0: FX disabled (bail out), 1: continue
slide_check_disable_fx:
        ld      a, (hl)
        cp      #0
        jr      z, _slide_check_disable
        ;; continue marker
        scf
        ret
_slide_check_disable:
        ;; stop FX
        ;; ld      SLIDE_CFG(ix), #0
        res     BIT_FX_SLIDE, FX(ix)
        ;; next position in the NSS stream
        inc     hl
        ;; bail out marker
        or      a
        ret


;;; Enable slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    b  : slide direction: 0 == up, 1 == down
;;;    c  : offset from ix of current note for channel
;;; [ hl ]: speed (4bits) and depth (4bits)
slide_init::
        call    slide_check_disable_fx
        jr      c, _slide_init_setup
        ret
_slide_init_setup:

        ;; FX configuration
        ld      a, b
        set     BIT_SLIDE_PORTAMENTO, a
        ld      SLIDE_CFG(ix), a

        push    bc
        push    de

        ;; d: depth (distance to target note)
        ld      a, (hl)
        and     #0xf
        ld      d, a

        ;; d: signed depth
        bit     0, b
        jr      z, _post_dist_sign
        xor     a
        sub     d
        ld      d, a
_post_dist_sign:

        ;; e: speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      e, a

        inc     hl
        push    hl

        ;; b: current note
        ;; TODO: make the note offset common to all track types
        push    ix
        pop     hl
        ld      a, l
        add     c
        ld      l, a
        ld      b, (hl)

        ;; init slide positions
        call    slide_init_source
        call    slide_init_target

        ;; c: increment size: 1/8th semitone
        ld      c, #3
        call    slide_init_increment

        set     BIT_FX_SLIDE, FX(ix)

        pop     hl
        pop     de
        pop     bc

        ret


;;; Enable pitch slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    b  : slide direction: 0 == up, 1 == down
;;;    c  : offset from ix of current note for channel
;;; [ hl ]: speed
slide_pitch_init::
        call    slide_check_disable_fx
        jr      c, _slide_pitch_init_setup
        ret

_slide_pitch_init_setup:
        ;; FX configuration
        ld      a, b
        set     BIT_SLIDE_PORTAMENTO, a
        ld      SLIDE_CFG(ix), a

        push    bc
        push    de

        ;; set up a default target bound, as per definition, pitch slides
        ;; do not have one (they rely on the stop FX in the music)
        bit     0, b
        jr      nz, _slide_pitch_init_direction
        ld      b, #UPMOST_NOTE
_slide_pitch_init_direction:
        ld      SLIDE_END(ix), b

        ;; setup slide increments
        ;; e: speed
        ld      e, (hl)
        inc     hl
        push    hl

        ;; b: current note
        ;; TODO: make the note offset common to all track types
        push    ix
        pop     hl
        ld      a, l
        add     c
        ld      l, a
        ld      b, (hl)

        ;; init slide start positions
        call    slide_init_source

        ;; c: increment size: 1/32 semitone
        ld      c, #5
        call    slide_init_increment

        set     BIT_FX_SLIDE, FX(ix)

        pop     hl
        pop     de
        pop     bc

        ret


;;; Enable portamento effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : current note for channel
;;; [ hl ]: speed
slide_portamento_init::
        push    bc
        ;; b: current note
        ld      b, a

        call    slide_check_disable_fx
        jr      c, _slide_portamento_init_setup
        pop     bc
        ret
_slide_portamento_init_setup:

        ;; FX configuration
        xor     a
        set     BIT_SLIDE_PORTAMENTO, a
        ld      SLIDE_CFG(ix), a

        push    de

        ;; configure slide source
        call    slide_init_source

        ;; setup slide increments
        ;; e: speed
        ld      e, (hl)
        inc     hl
        push    hl

        ;; c: increment size: 1/32 semitone
        ld      c, #5
        call    slide_init_increment

        ;; the slide target is configured with the next note opcode

        set     BIT_FX_SLIDE, FX(ix)

        pop     hl
        pop     de
        pop     bc

        ld      a, #1
        ret


;;; Update an ongoing slide effect with a new note
;;; ------
;;;   ix  : state for channel
;;;     c : current note for channel
;;;     b : new note for channel
;;; [ hl ]: speed
slide_update::
        bit     BIT_SLIDE_PORTAMENTO, SLIDE_CFG(ix)
        jr      nz, _slide_update_target

_slide_update_src:
        ld      SLIDE_POS16(ix), #0
        ld      SLIDE_POS16+1(ix), a
        ret

_slide_update_target:
        ;; d: offset to target
        ld      a, b
        sub     c
        ld      d, a
        ;; b: current note
        ld      b, c
        call    slide_init_target
        ret
