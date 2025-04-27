;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2025 Damien Ciabrini
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

;;; Trigger effect (delay, cut...), common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"


        .area  CODE


;;; ARPEGGIO
;;; Enable arpeggio chord for note playback
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: semitone:4 - semitone:4
;;; hl modified
arpeggio::
        ;; check whether this disables FX
        ld      a, (hl)
        cp      #0
        jr      nz, _arpeggio_init
        inc     hl
        res     BIT_FX_ARPEGGIO, FX(ix)
        ;; To fully clear the state after the FX is disabled, we must remember
        ;; to recompute the note and tune values without shift, so force it here
        ld      ARPEGGIO_POS8(ix), a
        set     BIT_LOAD_NOTE, PIPELINE(ix)
        ld      a, #1
        ret
_arpeggio_init:
        ;; 2nd note in chord
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      ARPEGGIO_2ND(ix), a

        ;; 3rd note in chord
        ld      a, (hl)
        and     #0xf
        ld      ARPEGGIO_3RD(ix), a

        inc     hl

        ;; init arpeggio state if it is not running already
        bit     BIT_FX_ARPEGGIO, FX(ix)
        jr      nz, _arpeggio_end
        ld      a, ARPEGGIO_SPEED(ix)
        ld      ARPEGGIO_COUNT(ix), a
        xor     a
        ld      ARPEGGIO_POS(ix), a
        ld      ARPEGGIO_POS8(ix), a

        set     BIT_FX_ARPEGGIO, FX(ix)

_arpeggio_end:
        ld      a, #1
        ret


;;; ARPEGGIO_SPEED
;;; configure the number of ticks between two notes of the chord
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: speed
;;; hl modified
arpeggio_speed::
        ld      a, (hl)
        inc     hl

        ld      ARPEGGIO_SPEED(ix), a

        ld      a, #1

        ret


;;; Update the arpeggio state for the current channel
;;; ------
;;; ix: mirrored state of the current channel
;;; [TODO modified]
eval_arpeggio_step::
        ;; assert: speed is always >=1, so count is never 0 here
        dec     ARPEGGIO_COUNT(ix)
        ld      a, ARPEGGIO_COUNT(ix)
        cp      #0
        jr      z, _arpeggio_update_pos
        ret
_arpeggio_update_pos:
        ;; rearm countdown
        ld      a, ARPEGGIO_SPEED(ix)
        ld      ARPEGGIO_COUNT(ix), a

        ;; update position in the arpeggio
        ld      a, ARPEGGIO_POS(ix)
        dec     a
        jp      p, _arpeggio_post_pos
        add     #3
_arpeggio_post_pos:
        ld      ARPEGGIO_POS(ix), a

        ;; set semitone offset according to position
        cp      #2
        jr      nz, _arpeggio_not2
        ;; pos == 2: 2nd note in chord
        ld      a, ARPEGGIO_2ND(ix)
        ld      ARPEGGIO_POS8(ix), a
        jr      _arpeggio_eval_end
_arpeggio_not2:
        cp      #1
        jr      nz, _arpeggio_not1
        ;; pos == 2: 3rd note in chord
        ld      a, ARPEGGIO_3RD(ix)
        ld      ARPEGGIO_POS8(ix), a
        jr      _arpeggio_eval_end
_arpeggio_not1:
        ;; 1st note in chord (0 displacement)
        ld      ARPEGGIO_POS8(ix), #0

_arpeggio_eval_end:
        ret
