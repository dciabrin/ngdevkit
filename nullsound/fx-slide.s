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


;;; Enable slide effect for the current SSG channel
;;; ------
;;;   ix  : FM state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;; [ hl ]: speed (4bits) and depth (4bits)
slide_init::
        ;; b: slide direction (from a)
        ld      b, a

        ;; slide fx on
        ld      a, FX(ix)
        set     1, a
        ld      FX(ix), a

        ;; a: speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ;; de: inc16 = speed / 8
        ld      d, a
        ld      e, #0
        srl     d
        rr      e
        srl     d
        rr      e
        srl     d
        rr      e
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

        ;; depth
        ld      a, (hl)
        and     #0xf
        ;; down: negate depth
        ;; we also need to go one seminote below, to account for the
        ;; fractional parts of the slide.
        bit     0, b
        jr      z, _post_depth_negate
        neg
        dec     a
_post_depth_negate:
        ld      SLIDE_DEPTH(ix), a

        inc     hl

        ret


;;; Setup the end semitone for the currently configured slide
;;; ------
;;; ix : state for channel
;;;  e : semitone to configure increments from
slide_setup_increments::
        push    bc
        push    de

        ;; init semitone position, fixed point representation
        ld      SLIDE_POS16+1(ix), e
        ld      a, #0
        ld      SLIDE_POS16(ix), a

        ;; d: depth, negative if slide goes down
        ld      d, SLIDE_DEPTH(ix)

        ;; c: note adjust. slide up: 4, slide down: -4
        ld      c, #4
        bit     7, d
        jr      z, _post_inc_adjust
        ld      c, #-4
_post_inc_adjust:

        ;; b: current octave
        ld      a, SLIDE_POS16+1(ix)
        and     #0xf0
        ld      b, a

        ;; e: target octave
        ld      a, SLIDE_POS16+1(ix)
        add     d
        and     #0xf0
        ld      e, a

        ;; if current and target octave differ, skip missing steps in the depth
        ld      a, b
        cp      e
        jr      z, _post_depth_adjust
        ld      a, d
        add     c               ; slide up: 4, slide down: -4
        ld      d, a
_post_depth_adjust:

        ;; a: current octave/note
        ld      a, SLIDE_POS16+1(ix)

        ;; d: target octave/note
        add     d
        ld      d, a

        ;; when target note is a missing step, adjust to the next note
        and     #0xf
        cp      #12
        ld      a, d
        jr      c, _post_target_note
        add     c             ; slide up: 4, slide down: -4
_post_target_note:
        ;; save target octave/note
        ld      SLIDE_END(ix), a

        pop     de
        pop     bc

        ret


;;; Get intermediate frequency distance between nearest semitones,
;;; based on the current fixed point semitone position.
;;; ----
;;; IN:
;;;    b: distance to next semitone
;;;    c: result frequency increment sign (0: positive, 1: negative)
;;;    e: intermediate distance to next semitone (fractional part)
;;; OUT:
;;;   de: intermediate frequency
slide_intermediate_freq:
        ;; The minimal slide change is 1/8 of a semitone each tick.
        ;; This distance `s_dist` between two semitones is encoded by
        ;; bits 7,6,5 of POS16, where:
        ;;     s_dist = [0.0, 1.0[
        ;; For the sake of speed and simplicity, only bits 7,6
        ;; are considered for computing the intermediate frequency
        ;; distance `f_dist` between the current and the next semitone.
        ;; so there are only 4 possible frequency distances:
        ;;     f_dist = {0.0, 1/4, 2/4, 3/4} * distance
        ;; which can be encoded as:
        ;;     f_dist = bit7 * 1/2 * distance + bit6 * 1/4 * distance
        ;;
        ;; compute frequency distance w.r.t semitone distance
        ld      a, #0
_chk_bit7:
        ;; bc: scaled semitone distance
        srl     b
        bit     7, e
        jr      z, _chk_bit6
        ;; freq distance -= 1/2*(semitone distance)
        add     b
_chk_bit6:
        srl     b
        bit     6, e
        jr      z, _post_chk
        ;; freq distance -= 1/4*(semitone distance)
        add     b

_post_chk:
        ;; check whether increment must be negative or positive:
        ;;   . the next semitone's value (period) in the SSG channel is always
        ;;     lower than the current semitone's, so `f_dist` must be negative.
        ;;   . the next semitone's value (f-num) in the FM channel is always
        ;;     higher than the current semitone's, so `f_dist` must be positive.
        bit     0, c
        jr      z, _post_sign_chk
        neg
_post_sign_chk:
        ;; de: extend the 8bit signed distance `f_dist` to 16bit
        ld      e, a
        add     a
        sbc     a
        ld      d, a

        ret


;;; Increment current fixed point position in the semitone table and
;;; stop effects when the target position is reached
;;; ------
;;; IN:
;;;   ix : state for channel
;;;    c : slide direction: 0 == up, 1 == down
;;; OUT:
;;;    a : whether effect is finished (0: finished, 1: still running)
;;;    d : when effect is finished, target semitone
eval_slide_step:
        ;; ix: state for the current channel
        push    hl
        pop     ix

        ;; c: 0 slide up, 1 slide down
        ld      a, SLIDE_INC16+1(ix)
        rlc     a
        and     #1
        ld      c, a

        ;; INC16 increment is 1/8 semitone (0x0020) * depth
        ;; negative for slide down

        ;; add/sub increment to the current semitone POS16
        ;; e: fractional part
        ld      a, SLIDE_INC16(ix)
        add     SLIDE_POS16(ix)
        ld      SLIDE_POS16(ix), a
        ld      e, a
        ;; d: integer part
        ld      a, SLIDE_INC16+1(ix)
        adc     SLIDE_POS16+1(ix)
        ld      d, a
        ;; do we need to skip missing steps in the note table
        and     #0xf
        cp      #0xc
        jr      c, _post_skip
        ld      a, d
        ;; slide direction
        bit     0, c
        jr      z, _slide_dist_up
        add     #-4
        ld      d, a
        jr      _post_skip
_slide_dist_up:
        add     #4
        ld      d, a
_post_skip:
        ld      SLIDE_POS16+1(ix), d

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
        jr      c, _slide_intermediate

        ;; slide is finished, stop effect
        ld      (ix), #0

        ;; d: clamp the last slide pos to the target semitone
        ld      d, SLIDE_END(ix)

        ;; for slide down, we finish one note below the real target to play
        ;; all ticks with fractional parts. Adjust the end note back if needed
        bit     0, c
        jr      z, _post_adjust
        ld      a, d
        and     #0xf
        cp      #11
        jr      c, _neg_inc_adjust
        ;; adjust to next note (after the missing steps in the note table)
        ld      a, d
        add     #5
        ld      d, a
        jr      _post_adjust
_neg_inc_adjust:
        ;; adjust to next note
        ld      a, d
        inc     a
        ld      d, a
_post_adjust:
        ;; effect is finished, new semitone in d
        ld      a, #0
        ret

_slide_intermediate:
        ;; effect is still running
        ld      a, #1
        ret
