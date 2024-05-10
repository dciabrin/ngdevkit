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

;;; Vibrato effect, common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"

        .area  CODE


;;; Setup prev and next increments for vibrato
;;; ------
;;; IN:
;;;   ix  : fm state for channel
;;;         the note semitone must be already configured
;;; [ hl ]: prev semitone distance
;;; [hl+1]: next semitone distance
;;; OUT:
;;;    de : prev increment (fixed-point)
;;;    hl : prev increment (fixed-point)
;;; bc, de, hl modified
vibrato_setup_increments::
        ;; bc: prev distance from current note
        push    hl              ; +(prev distance)
        ld      b, (hl)
        ;; de: output prev increment, scaled by depth (a)
        ld      a, VIBRATO_DEPTH(ix)
        call    vibrato_scale_increment
        ld      e, l
        ld      d, h

        ;; bc: next distance from current note
        pop     hl              ; (prev distance)
        inc     hl
        ld      b, (hl)
        ;; hl: output next increment, scaled by depth (a)
        ld      a, VIBRATO_DEPTH(ix)
        call    vibrato_scale_increment

        ret


;;; Scale a fixed point 16bit value into x/16 fraction
;;; ------
;;; IN:
;;;   bc : distance
;;;    a : scale factor [1..16]
;;; OUT:
;;;   hl : scaled base increment
;;; bc, hl modified
vibrato_scale_increment:
        ;; bc: base increment (fixed point)
        ;; there are 8 possible levels, so bc = fixed point distance / 8
        ld      c, #0
        srl     b
        rr      c
        srl     b
        rr      c
        srl     b
        rr      c

        ;; scale the base increment based on the vibrato depth
        ;; depth has 16 possible levels [1..16], so parse 4 bits
        ld      h, #0
        ld      l, h
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


;;; Update the vibrato for the current channel
;;; Vibrato oscillates the current note's frequency between the previous
;;; and the next semitones of the current note, and follows a sine wave.
;;; This function update the frequency by one step among the 64 steps
;;; defined in the sine wave.
;;; ------
;;; IN:
;;;   ix: mirrored state of the current fm channel
;;; OUT:
;;;   hl: new note for step (FM: f-num, SSG: period)
;;; bc, de, hl modified
vibrato_eval_step::
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

        ret
