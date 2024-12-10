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

        .area  CODE


;;; Initialize slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;;    c  : increment size (increment = 1/2^c)
;;;    h  : speed (increments)
;;;    l  : depth (target semitone)
;;; bc, de modified
slide_init_common::
        ;; b: slide direction (from a)
        ld      b, a

        ;; if the slide is already running, keep its internal
        ;; state, otherwise initialize it.
        bit     BIT_FX_SLIDE, FX(ix)
        jr      nz, _post_enable_slide
        xor     a
        ld      SLIDE_POS16(ix), a
        ld      SLIDE_POS16+1(ix), a
        set     BIT_FX_SLIDE, FX(ix)

_post_enable_slide:

        ;; de: inc16 = speed / 2^c
        ld      d, h
        ld      e, #0
__slide_divide:
        srl     d
        rr      e
        dec     c
        jr      nz, __slide_divide

        ;; down: negate inc16
        bit     0, b
        jr      z, __post_inc16_negate
        ld      a, #0
        sub     e
        ld      e, a
        ld      a, #0
        sbc     d
        ld      d, a
__post_inc16_negate:
        ld      SLIDE_INC16(ix), e
        ld      SLIDE_INC16+1(ix), d

        ;; depth
        ld      a, l
        ;; down: negate depth
        ;; we also need to go one seminote below, to account for the
        ;; fractional parts of the slide.
        bit     0, b
        jr      z, __post_depth_negate
        neg
        dec     a
__post_depth_negate:
        ld      SLIDE_DEPTH(ix), a

        ;; save target is the current position + new displacement
        ld      a, SLIDE_DEPTH(ix)
        add     SLIDE_POS16+1(ix)
        ld      SLIDE_END(ix), a

        ret


;;; Initialize slide increment for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;;    c  : increment size (increment = 1/2^c)
;;;    d  : speed (increments)
;;; bc, de modified
slide_init_setup_increment::
        ;; b: slide direction (from a)
        ld      b, a

        ;; de: inc16 = speed / 2^c
        ld      e, #0
_slide_divide:
        srl     d
        rr      e
        dec     c
        jr      nz, _slide_divide

        ;; down: negate inc16
        bit     0, b
        jr      z, _post_inc16_negate
        ld      a, #0
        sub     e
        ld      e, a
        ld      a, #0
        sbc     d
        ld      d, a
_post_inc16_negate:
        ld      SLIDE_INC16(ix), e
        ld      SLIDE_INC16+1(ix), d

        ret


;;; Initialize slide depth target for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;;    c  : depth (target semitone)
;;; bc modified
slide_init_depth_target::
        ;; b: slide direction (from a)
        ld      b, a

        ;; depth
        ld      a, c
        ;; down: negate depth
        ;; we also need to go one seminote below, to account for the
        ;; fractional parts of the slide.
        bit     0, b
        jr      z, _post_depth_negate
        neg
        dec     a
_post_depth_negate:
        ld      SLIDE_DEPTH(ix), a

        ;; init semitone position, fixed point representation
        ld      a, #0
        ld      SLIDE_POS16(ix), a
        ld      SLIDE_POS16+1(ix), a

        ;; save target depth
        ld      a, SLIDE_DEPTH(ix)
        ld      SLIDE_END(ix), a

        ret


;;; Get intermediate frequency distance between nearest semitones,
;;; based on the current fixed point semitone position.
;;; ----
;;; IN:
;;;    b: fractional note position (distance to next semitone)
;;;    c: result frequency increment sign (0: positive, 1: negative)
;;;    e: half-distance to next ym2610 note frequency
;;; OUT:
;;;   hl: intermediate frequency
;;; bc, de, hl modified
slide_intermediate_freq:
        ;; The distance between two semitones is the fraction part
        ;; encoded by bits 7,6,5,... of POS16, where:
        ;;     distance = [0.0, 1.0[
        ;; For the sake of speed and simplicity, only bits 7,6,5
        ;; are considered for computing the intermediate frequency
        ;; between the current and the next ym2610 frequency value,
        ;; which can be encoded as:
        ;;     frequency = bit7 * 1/2 * distance +
        ;;                 bit6 * 1/4 * distance +
        ;;                 bit5 * 1/8 * distance +
        ;;                 ...
        ;; or with out precalc distances:
        ;;     frequency = bit7 *  1  * half_distance +
        ;;                 bit6 * 1/2 * half_distance +
        ;;                 bit5 * 1/4 * half_distance +
        ;;                 ...
        ;;
        ;; compute frequency distance w.r.t semitone distance
        ld      hl, #0
        ld      d, h
_chk_bit7:
        bit     7, b
        jr      z, _chk_bit6
        ;; freq distance -= 1/2*(semitone distance)
        add     hl, de
_chk_bit6:
        srl     e
        bit     6, b
        jr      z, _chk_bit5
        ;; freq distance -= 1/4*(semitone distance)
        add     hl, de
_chk_bit5:
        srl     e
        bit     5, b
        jr      z, _chk_bit4
        ;; freq distance -= 1/8*(semitone distance)
        add     hl, de
_chk_bit4:
        srl     e
        bit     4, b
        jr      z, _post_chk
        ;; freq distance -= 1/16*(semitone distance)
        add     hl, de

_post_chk:
        ;; check whether increment must be negative or positive:
        ;;   . the next semitone's value (period) in the SSG channel is always
        ;;     lower than the current semitone's, so `f_dist` must be negative.
        ;;   . the next semitone's value (f-num) in the FM channel is always
        ;;     higher than the current semitone's, so `f_dist` must be positive.
        bit     0, c
        jr      z, _post_sign_chk
        push    hl
        pop     de
        ld      hl, #0
        or      a
        sbc     hl, de
_post_sign_chk:

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
;;; bc, de modified
eval_slide_step:
        ;; c: 0 slide up, 1 slide down
        ld      a, SLIDE_INC16+1(ix)
        rlc     a
        and     #1
        ld      c, a

        ;; add/sub increment to the current semitone displacement POS16
        ;; e: fractional part
        ld      a, SLIDE_INC16(ix)
        add     SLIDE_POS16(ix)
        ld      SLIDE_POS16(ix), a
        ld      e, a
        ;; d: integer part
        ld      a, SLIDE_INC16+1(ix)
        adc     SLIDE_POS16+1(ix)
        ld      SLIDE_POS16+1(ix), a
        ld      d, a

        ;; have we reached the end of the slide?
        ;; slide up:   continue if cur < end
        ;; slide down: continue if end < cur
        bit     0, c
        jr      z, _slide_cp_up
        ld      a, SLIDE_END(ix)
        jr      _slide_cp
_slide_cp_up:
        ld      a, d
        ld      d, SLIDE_END(ix)
_slide_cp:
        cp      d
        jp      m, _slide_intermediate

        ;; slide is finished, stop effect and clear FX state
        res     BIT_FX_SLIDE, FX(ix)
        xor     a
        ld      SLIDE_PORTAMENTO(ix), a
        ld      SLIDE_POS16(ix), a
        ld      SLIDE_POS16+1(ix), a

        ;; d: clamp the last slide pos to the target displacement
        ld      d, SLIDE_END(ix)

        ;; for slide down, we finish one note below the real target to play
        ;; all ticks with fractional parts. Adjust the end displacement back if needed
        bit     0, c
        jr      z, _post_adjust
        inc     d
_post_adjust:
        ;; effect is finished, new displacement in d
        ld      a, #0
        ret

_slide_intermediate:
        ;; effect is still running
        ld      a, #1
        ret


;;; Check whether the slide NSS opcode should disable the current slide FX
;;; When disabling the FX, update the current NOTE position with the last
;;; slide displacement.
;;; ------
;;;   ix  : state for channel
;;;    c  : offset from ix of current note for channel
;;; [ hl ]: 0 means disable FX, otherwise bail out
slide_check_disable_fx:
        ld      a, (hl)
        cp      #0
        jr      z, _slide_check_disable
        ;; set carry flag
        scf
        ret
_slide_check_disable:
        inc     hl
        push    hl
        ;; hl: offset of note from current channel context
        push    ix
        pop     hl
        ld      b, #0
        add     hl, bc
        ;; update current note with slide displacement
        ld      a, (hl)
        add     SLIDE_POS16+1(ix)
        ld      (hl), a
        pop     hl
        ;; stop FX
        res     BIT_FX_SLIDE, FX(ix)
        ;; clear carry flag
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
        ;; null input means 'disable FX', in that case,
        ;; update current note with slide displacement and exit
        jr      c, _slide_init_setup
        ret
_slide_init_setup:
        ;; a: slide direction
        ld      a, b

        push    de

        ;; d: slide direction
        ld      d, a

        ;; c: depth
        ld      a, (hl)
        and     #0xf
        ld      c, a

        ;; b: speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      b, a

        inc     hl
        push    hl

        ;; setup the slide
        ;; h: speed
        ld      h, b
        ;; l: depth
        ld      l, c
        ;; c: increment size
        ld      c, #3
        ;; a: direction
        ld      a, d
        call    slide_init_common

        pop     hl
        pop     de

        ret


;;; Enable pitch slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    b  : slide direction: 0 == up, 1 == down
;;;    c  : offset from ix of current note for channel
;;; [ hl ]: speed
slide_pitch_init::
        call    slide_check_disable_fx
        ;; null input means 'disable FX', in that case,
        ;; update current note with slide displacement and exit
        jr      c, _slide_pitch_init_setup
        ret
_slide_pitch_init_setup:
        ;; a: slide direction
        ld      a, b

        push    de

        ;; d: slide direction
        ld      d, a

        ;; b: speed
        ld      b, (hl)
        inc     hl
        push    hl

        ;; setup the slide
        ;; h: speed
        ld      h, b
        ;; l: depth
        ld      l, #127
        ;; c: increment size
        ld      c, #5
        ;; a: direction
        ld      a, d
        call    slide_init_common

        pop     hl
        pop     de

        ret


;;; Finish initializing the slide effect for the target note
;;; ------
;;;   ix  : state for channel, speed increment already initialized
;;;    b  : current note for channel
;;; bc modified
slide_portamento_finish_init::
        ;; setup the slide

        ;; a: distance from current slide position
        ld      a, SLIDE_PORTAMENTO(ix)
        sub     b
        sub     SLIDE_POS16+1(ix)
        jr      nc, _slide_post_distance
        neg
_slide_post_distance:

        push    de
        push    hl

        ;; l: depth (distance from current slide)
        ld      l, a
        ;; a: slide direction from current slide position
        ld      a, #0
        rl      a
        ;; h: speed
        ld      h, SLIDE_SPEED(ix)
        ;; c: increment size
        ld      c, #5
        call    slide_init_common

        pop     hl
        pop     de

        ret


;;; Enable portamento effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;     a : current note for channel
;;; [ hl ]: speed
slide_portamento_init::

        ;; mark this slide as being a portamento by setting a non-null
        ;; portamento target. This is not the real target yet...
        set     BIT_FX_SLIDE, FX(ix)
        ld      a, #-1
        ld      SLIDE_PORTAMENTO(ix), a

        ;; ... the portamento increments can only be fully initialized when
        ;; the real target note is known. This is only the case when we reach
        ;; the next note NSS opcode.
        ;; So mark the slide FX  as `to be initialized`
        ;; (end == to be initialized)
        xor     a
        ld      SLIDE_END(ix), a

        ;; a: speed
        ld      a, (hl)
        ld      SLIDE_SPEED(ix), a
        inc     hl

        ld      a, #1
        ret
