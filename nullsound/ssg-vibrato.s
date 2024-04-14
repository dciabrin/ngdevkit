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

;;; SSG vibrato effect. This file is included by nss-ssg.s
;;;

        .equ    VIBRATO_SPEED,(state_vibrato_speed-state_mirrored_ssg)
        .equ    VIBRATO_DEPTH,(state_vibrato_depth-state_mirrored_ssg)
        .equ    VIBRATO_POS,(state_vibrato_pos-state_mirrored_ssg)
        .equ    VIBRATO_PREV,(state_vibrato_prev-state_mirrored_ssg)
        .equ    VIBRATO_NEXT,(state_vibrato_next-state_mirrored_ssg)


;;; Update the vibrato for the current SSG channel
;;; Vibrato oscillates the current note's frequency between the previou
;;; and the next semitones of the current note, and follows a sine wave.
;;; This function update the frequency by one step among the 64 steps
;;; defined in the sine wave.
;;; ------
;;; hl: mirrored state of the current ssg channel
eval_ssg_vibrato_step::
        push    hl
        push    de
        push    bc

        ;; ix: mirrored_ssg for current channel
        push    hl
        pop     ix

        ;; e: next vibrato pos
        ld      a, VIBRATO_POS(ix)
        add     a, VIBRATO_SPEED(ix)
        and     #63
        ld      e, a
        ld      VIBRATO_POS(ix), a

        ;; hl: pos in sine precalc
        ld      hl, #sine
        ld      a, l
        add     e
        ld      l, a

        ;; a: sine precalc (a2a1a0)
        ld      a, (hl)

        ;; bc: increment for next or previous semitone based on
        ;; precalc's sign (a3)
        bit     3, a
        jr      z, _prev_semitone
        ld      c, VIBRATO_NEXT(ix)
        ld      b, VIBRATO_NEXT+1(ix)
        jr      _post_increment
_prev_semitone:
        ld      c, VIBRATO_PREV(ix)
        ld      b, VIBRATO_PREV+1(ix)
_post_increment:

        ;; scale increment (with scale precalc)

        ;; multiply increment by the precalc factor (0..7)
        ld      h, b
        ld      l, c
        add     hl, hl
        ld      d, h
        ld      e, l
        add     hl, hl
        bit     2, a
        jr      nz, _post_mul_a2
        ld      h, #0
        ld      l, h
_post_mul_a2:
        bit     1, a
        jr      z, _post_mul_a1
        add     hl, de
_post_mul_a1:
        bit     0, a
        jr      z, _post_mul_a0
        add     hl, bc
_post_mul_a0:
        ;; hl is now bc * magnitude(a), keep the integral part only
        ;; and extend sign to 16bits
        ld      a, h
        ld      l, a
        add     a
        sbc     a
        ld      h, a

        ;; de: current note freq
        ld      e, NOTE_OFFSET(ix)
        ld      d, NOTE_OFFSET+1(ix)
        ;; hl: new note
        add     hl, de

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

        pop     bc
        pop     de
        pop     hl

        ret 


;;; Setup prev and next increments for vibrato
;;; ------
;;; ix : ssg state for channel
;;;      the note semitone must be already configured
ssg_vibrato_setup_increments::
        push    bc
        push    hl

        ;; reset vibrato sine pos
        ld      VIBRATO_POS(ix), #0

        ;; bc: prev distance from current note, fix point
        ld      hl, #ssg_semitone_distance
        ld      l, NOTE_SEMITONE_OFFSET(ix)
        push    hl              ; +prev distance
        ld      b, (hl)
        ld      c, #0
        ;; a: vibrato depth
        ld      a, VIBRATO_DEPTH(ix)
        ;; hl: output prev increment, scaled by depth (a)
        ld      h, #0
        ld      l, h
        call    ssg_vibrato_scale_increment
        ld      VIBRATO_PREV(ix), l
        ld      VIBRATO_PREV+1(ix), h

        ;; bc: next distance
        pop     hl              ; prev distance
        inc     hl
        ld      b, (hl)
        ld      c, #0
        ;; a: vibrato depth
        ld      a, VIBRATO_DEPTH(ix)
        ;; hl: output next increment, scaled by depth (a)
        ld      h, #0
        ld      l, h
        call    ssg_vibrato_scale_increment
        ;; hl: -hl (next increment is always negative)
        xor     a
        sub     l
        ld      l, a
        sbc     a, a
        sub     h
        ld      h, a
        ld      VIBRATO_NEXT(ix), l
        ld      VIBRATO_NEXT+1(ix), h

        pop     hl
        pop     bc
        ret


;;; Scale a fixed point 16bit value into x/16 fraction
;;; ------
;;; IN:
;;;   bc : distance
;;;    a : scale factor [1..16]
;;; OUT:
;;;   hl : scaled base increment
;;; bc, hl modified
ssg_vibrato_scale_increment:
        ;; bc: get base increment
        ;; there are 8 possible levels, so bc = distance / 8
        srl     b
        rr      c
        srl     b
        rr      c
        srl     b
        rr      c

        ;; scale the base increment based on the vibrato depth
        ;; depth has 16 possible levels [1..16], so parse 4 bits
        bit     4, a
        jr      z, _post_bit4
        add     hl, bc
_post_bit4:
        ;; shift bc 1 bit to the right
        srl     b
        rr      c
        bit     3, a
        jr      z, _post_bit3
        add     hl, bc
_post_bit3:
        srl     b
        rr      c
        bit     2, a
        jr      z, _post_bit2
        add     hl, bc
_post_bit2:
        srl     b
        rr      c
        bit     1, a
        jr      z, _post_bit1
        add     hl, bc
_post_bit1:
        ret
