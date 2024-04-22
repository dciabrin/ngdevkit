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

;;; SSG slide effects. This file is included by nss-ssg.s
;;;

        .equ    SLIDE_SPEED,(state_slide_speed-state_mirrored_ssg)
        .equ    SLIDE_DEPTH,(state_slide_depth-state_mirrored_ssg)
        .equ    SLIDE_INC16,(state_slide_inc16-state_mirrored_ssg)
        .equ    SLIDE_POS16,(state_slide_pos16-state_mirrored_ssg)
        .equ    SLIDE_END,(state_slide_end-state_mirrored_ssg)


;;; Update the slide for the current SSG channel
;;; Slide moves up or down by 1/8 of semitone increments * slide depth.
;;; ------
;;; hl: mirrored state of the current ssg channel
eval_ssg_slide_step::
        push    hl
        push    de
        push    bc
        push    ix

        ;; ix: mirrored_ssg for current channel
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
        ;; jr      nz, _slide_intermediate
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
        ;; save new current note semitone
        ld      NOTE_SEMITONE_OFFSET(ix), d

        ;; hl: new current note frequency
        ld      a, d
        ld      bc, #ssg_tune
        sla     a
        ld      c, a
        ld      a, (bc)
        ld      l, a
        inc     bc
        ld      a, (bc)
        ld      h, a
        inc     bc

        ;; save new current note frequency
        ld      NOTE_OFFSET(ix), l
        ld      NOTE_OFFSET+1(ix), h

        ;; load new current note in the YM2610 and finish
        jr      _slide_load_note

_slide_intermediate:
        ;; d: current pos. TODO tidy up
        ld      d, SLIDE_POS16+1(ix)

        ;; bc: next semitone distance from current note, fixedpoint
        ld      hl, #ssg_semitone_distance
        ld      l, d
        inc     l
        ld      b, (hl)
        ld      c, #0

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
        ;; NOTE: the frequency of the next semitone in the SSG channel
        ;; is always lower than the current semitone, so the intermediate
        ;; distance `f_dist` is computed as a negative number.

        ;; compute frequency distance w.r.t semitone distance
        ld      a, #0
_chk_bit7:
        ;; bc: scaled semitone distance
        srl     b
        bit     7, e
        jr      z, _chk_bit6
        ;; freq distance -= 1/2*(semitone distance)
        sub     b
_chk_bit6:
        srl     b
        bit     6, e
        jr      z, _post_chk
        ;; freq distance -= 1/4*(semitone distance)
        sub     b

_post_chk:

        ;; hl: extend the 8bit signed distance `f_dist` to 16bit
        ld      l, a
        add     a
        sbc     a
        ld      h, a

        ;; de: note frequency
        ld      bc, #ssg_tune
        ld      a, d
        sla     a
        ld      c, a
        ld      a, (bc)
        ld      e, a
        inc     bc
        ld      a, (bc)
        ld      d, a

        ;; hl: semitone frequency - |f_dist|
        add     hl, de

_slide_load_note:
        ;; configure SSG channel with new note
        ;; TODO, update the mirror state only
        ld      a, (state_ssg_channel)
        sla     a
        ld      b, a
        ld      c, l
        call    ym2610_write_port_a
        inc     b
        ld      c, h
        call    ym2610_write_port_a


        pop     ix
        pop     bc
        pop     de
        pop     hl

        ret


;;; Setup the end semitone for the currently configured slide
;;; ------
;;; ix : ssg state for channel
;;;      the note semitone must be already configured
ssg_slide_setup_increments::
        push    bc
        push    de

        ;; d: depth, negative if slide goes down
        ld      d, SLIDE_DEPTH(ix)

        ;; c: note adjust. slide up: 4, slide down: -4
        ld      c, #4
        bit     7, d
        jr      z, _post_inc_adjust
        ld      c, #-4
_post_inc_adjust:

        ;; b: current octave
        ld      a, NOTE_SEMITONE_OFFSET(ix)
        and     #0xf0
        ld      b, a

        ;; e: target octave
        ld      a, NOTE_SEMITONE_OFFSET(ix)
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
        ld      a, NOTE_SEMITONE_OFFSET(ix)

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

        ;; init: note frequency
        ld      a, NOTE_SEMITONE_OFFSET(ix)
        ld      SLIDE_POS16+1(ix), a
        ld      a, #0
        ld      SLIDE_POS16(ix), a

        pop     de
        pop     bc

        ret


;;; Enable slide effect for the current SSG channel
;;; ------
;;;    a  : slide direction: 0 == up, 1 == down
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_slide_common::
        push    bc
        push    de

        ;; b: slide direction (from a)
        ld      b, a

        ;; de: fx for channel (expect: from mirrored_ssg)
        ld      de, #state_fx
        call    mirrored_ssg_for_channel

        ;; ix: ssg state for channel
        push    de
        pop     ix

        ;; vibrato fx on
        ld      a, SSG_FX(ix)
        set     1, a
        ld      SSG_FX(ix), a

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

        ;; increments for last configured note
        call    ssg_slide_setup_increments

        inc     hl

        pop     de
        pop     bc

        ret
