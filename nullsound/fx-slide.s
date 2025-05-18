;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024-2025 Damien Ciabrini
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

;;; Slide effect, common functions for all channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"



        .area  CODE


;;; Setup the fixed-point increment for the slide
;;; ------
;;;   iy  : FX state for channel
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
        ld      SLIDE_INC16(iy), e
        ld      SLIDE_INC16+1(iy), d

        ret


;;; Initialize the source value for the slide
;;; ------
;;;   ix  : state for channel
;;;   iy  : FX state for channel
;;;    b  : current value
slide_init_source::
        ;; init slide position if no slide FX is ongoing
        bit     BIT_FX_SLIDE, DATA_FX(iy)
        jr      nz, _post_init_slide
        ld      DATA16(iy), #0
        ld      DATA16+1(iy), b
_post_init_slide:
        ret


;;; Initialize a target value for the slide
;;; ------
;;;   iy  : state for channel
;;;    b  : current value
;;;    d  : target offset (signed)
slide_init_target::
        ;; init slide direction
        res     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)

        ;; slide target is the current position + new displacement
        ;; a: target note
        ld      a, b
        add     d
        ;; down: we also need to go one seminote below, to account
        ;; for the fractional parts of the slide.
        ;; TODO check/fix ADPCM-B volume, as it uses bit7
        bit     7, d
        jr      z, _post_neg_slide
        set     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)
        dec     a
_post_neg_slide:
        ld      SLIDE_END(iy), a
        xor     a
        sbc     a
        ld      SLIDE_END+1(iy), a

        ret


;;; Increment current fixed point displacement and
;;; stop effects when the target displacement is reached
;;; ------
;;; IN:
;;;   ix : state for channel
;;;   iy : FX state for channel
;;; bc, de, hl modified
eval_slide_step:
        ;; bc: increment
        ld      c, SLIDE_INC16(iy)
        ld      b, SLIDE_INC16+1(iy)
        ;; hl: decimal note (FX copy)
        ld      l, DATA16(iy)
        ld      h, DATA16+1(iy)

        ;; c: 0 slide up, 1 slide down
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)
        jr      nz, _slide_sub_inc

_slide_add_inc:
        ;; de: pos16+inc16
        add     hl, bc
        ex      de, hl
        ;; bc: 00xx (end vol)
        ld      c, SLIDE_END(iy)
        ld      b, SLIDE_END+1(iy)
        ;; lh: new pos16 MSB
        ld      l, d
        ld      h, #0
        jr      _slide_cp
_slide_sub_inc:
        ;; de: pos16-inc16
        or      a
        sbc     hl, bc
        ex      de, hl
        ;; bc: new pos16 MSB
        ld      a, #0
        sbc     a
        ld      b, a
        ld      c, d
        ;; lh: 00xx (end vol) or ffff (-1)
        ld      l, SLIDE_END(iy)
        ld      h, SLIDE_END+1(iy)

        ;; have we reached the end of the slide?
        ;; slide up:   continue if cur < end
        ;; slide down: continue if end < cur
        ;; note: we don't check for equality because the increment
        ;; can go past the target note
_slide_cp:
        or      a
        sbc     hl, bc
        jp      m, _slide_intermediate

        ;; slide has reached its target

        ;; hl: clamp the last slide pos to the target displacement
        ld      d, SLIDE_END(iy)
        ld      e, #0

        ;; for slide down, we finish one note below the real target to play
        ;; all ticks with fractional parts. Adjust the end displacement back if needed
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)
        jr      z, _slide_post_sub_clamp
        inc     d
_slide_post_sub_clamp:
        ;; slide is finished, set the configured data to this new position
        ld      DATA_CFG(iy), d

        ;; only stop the FX if requested
        bit     BIT_SLIDE_KEEP_RUNNING, SLIDE_CFG(iy)
        jr      nz, _slide_intermediate
        res     BIT_FX_SLIDE, DATA_FX(iy)

_slide_intermediate:
        ;; effect is still running
        ld      DATA16(iy), e
        ld      DATA16+1(iy), d

        ret


;;; Initialize a slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide configuration (direction, ending...)
;;;    c  : increment size (1/2^c)
;;;   de  : offset to the note or vol FX state
;;; [ hl ]: increment
;;; iy modified
slide_init::
        ;; iy: FX state for channel
        push    ix
        pop     iy
        add     iy, de

        ;; FX configuration
        ld      SLIDE_CFG(iy), a

        ;; e: speed
        ld      e, (hl)
        inc     hl
        push    hl

        ;; setup tick increment based on speed (e) and increment size (c)
        call    slide_init_increment

        ;; init slide source if FX is starting (use current value)
        ld      b, DATA_CFG(iy)
        call    slide_init_source

        ;; set up a default target bound, as per definition, plain slides
        ;; do not have one (they rely on the stop FX in the music)
        ld      bc, #-1
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)
        jr      nz, _slide_init_direction
        ld      b, #0
        ld      c, SLIDE_MAX(iy)
_slide_init_direction:
        ld      SLIDE_END(iy), c
        ld      SLIDE_END+1(iy), b
        set     BIT_FX_SLIDE, DATA_FX(iy)

        pop     hl

        ;; pop the vol of note config
        pop     de
        pop     bc

        ld      a, #1
        ret


;;; Initialize a slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide configuration (direction, ending...)
;;;    c  : increment size (1/2^c)
;;;   de  : offset to the note or vol FX state
;;; [ hl ]: speed (4bits) and depth (4bits)
;;; iy modified
slide_init_with_target::
        ;; iy: FX state for channel
        push    ix
        pop     iy
        add     iy, de

        ;; FX configuration
        set     BIT_SLIDE_PORTAMENTO, a
        ld      SLIDE_CFG(iy), a

        ;; d: depth (signed distance to target note)
        ld      a, (hl)
        and     #0xf
        bit     BIT_SLIDE_DIRECTION, SLIDE_CFG(iy)
        jr      z, _targey_post_depth
        neg
_targey_post_depth:
        ld      d, a

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

        ;; b: current value
        ld      b, DATA_CFG(iy)

        ;; init slide positions (absolute value)
        call    slide_init_source
        call    slide_init_target

        ;; setup tick increment based on speed (e) and increment size (c)
        call    slide_init_increment

        set     BIT_FX_SLIDE, DATA_FX(iy)

        pop     hl
        ;; pop the vol of note config
        pop     de
        pop     bc

        ld      a, #1
        ret


;;; Initialize a slide portamento effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide configuration (direction, ending...)
;;;    c  : increment size (1/2^c)
;;;   de  : offset to the note or vol FX state
;;; [ hl ]: speed
;;; iy modified
slide_portamento_init::
        ;; iy: FX state for channel
        push    ix
        pop     iy
        add     iy, de

        ;; FX configuration
        xor     a
        set     BIT_SLIDE_PORTAMENTO, a
        ld      SLIDE_CFG(iy), a

        ;; e: speed
        ld      e, (hl)
        inc     hl
        push    hl

        ;; setup tick increment based on speed (e) and increment size (c)
        call    slide_init_increment

        ;; init slide source if FX is starting (use current value)
        ld      b, DATA_CFG(iy)
        call    slide_init_source

        set     BIT_FX_SLIDE, DATA_FX(iy)

        pop     hl
        ;; pop the vol of note config
        pop     de
        pop     bc

        ld      a, #1
        ret


;;; Update an ongoing slide effect with a new value (note or volume)
;;; ------
;;;   ix  : state for channel
;;;   bc  : offset to the note or vol FX state
;;;     a : new value for channel
;;; bc modified
slide_update::
        ;; iy: volume FX state for channel
        push    ix
        pop     iy
        add     iy, bc

        ;; if the slide is a portamento, only update the slide target
        bit     BIT_SLIDE_PORTAMENTO, SLIDE_CFG(iy)
        jr      nz, _slide_update_target

_slide_update_src:
        ;; else configure this new note as the current decimal note
        ;; and make sure to play it at next pipeline run
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        ld      DATA_CFG(iy), a
        ld      DATA16+1(iy), a
        ld      DATA16(iy), #0
        ret

_slide_update_target:
        ld      c, d
        ;; b: current value
        ld      b, DATA_CFG(iy)
        ;; d: displacement (new value - current value)
        sub     b
        ld      d, a
        call    slide_init_target
        ld      d, c
        ret


;;; Stop a slide effect in progress for the current channel
;;; ------
;;; iy modified
slide_off::
        ;; iy: FX state for channel
        push    ix
        pop     iy
        add     iy, de

        res     BIT_FX_SLIDE, DATA_FX(iy)

        pop     de
        ld      a, #1
        ret


;;;
;;; VOLUME NSS OPCODES
;;; ----------------


;;; VOL_SLIDE_OFF
;;; Stop the volume slide effect in progress for the current channel
;;; ------
;;; iy modified
vol_slide_off::
        push    de
        ld      de, #VOL_CTX
        ;; since we disable the FX outside of the pipeline process
        ;; make sure to load this new volume at next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)
        jp      slide_off


;;; VOL_SLIDE_UP/DOWN
;;; Enable volume slide effect for the current channel
;;; ------
;;; [ hl ]: increment
__vol_slide::
        push    bc
        ld      c, #2
        push    de
        ld      de, #VOL_CTX
        set     BIT_SLIDE_KEEP_RUNNING, a
        jp      slide_init
vol_slide_up::
        ld      a, #0
        jp      __vol_slide
vol_slide_down::
        ld      a, #1
        jp      __vol_slide


;;;
;;; NOTE NSS OPCODES
;;; ----------------


;;; NOTE_PITCH_SLIDE_UP/DOWN
;;; Enable note pitch slide effect for the current channel
;;; ------
;;; [ hl ]: increment
__note_pitch_slide::
        push    bc
        ld      c, #5
        push    de
        ld      de, #NOTE_CTX
        jp      slide_init
note_pitch_slide_up::
        ld      a, #0
        jp      __note_pitch_slide
note_pitch_slide_down::
        ld      a, #1
        jp      __note_pitch_slide


;;; NOTE_PORTAMENTO
;;; Enable note pitch slide effect for the current channel
;;; ------
;;; [ hl ]: speed
note_portamento::
        push    bc
        ld      c, #5
        push    de
        ld      de, #NOTE_CTX
        xor     a
        jp      slide_portamento_init


;;; NOTE_SLIDE_UP/DOWN
;;; Enable note slide effect for the current channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
__note_slide::
        push    bc
        ld      c, #3
        push    de
        ld      de, #NOTE_CTX
        jp      slide_init_with_target
note_slide_up::
        ld      a, #0
        jp      __note_slide
note_slide_down::
        ld      a, #1
        jp      __note_slide


;;; NOTE_SLIDE_OFF
;;; Stop the note slide effect in progress for the current channel
;;; ------
;;; iy modified
note_slide_off::
        push    de
        ld      de, #NOTE_CTX
        ;; since we disable the FX outside of the pipeline process
        ;; make sure to load this new note at next pipeline run
        set     BIT_LOAD_NOTE, PIPELINE(ix)
        jp      slide_off
