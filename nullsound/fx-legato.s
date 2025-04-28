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


;;; QUICK_LEGATO
;;; Change pitch (up/down) by a some semitones, after some ticks have passed
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: direction/ticks:4 - transpose:4
;;; hl modified
quick_legato::
        push    bc

        ;; b: transpose (unsigned)
        ld      a, (hl)
        and     #0xf
        ld      b, a

        ;; c: delay before transpose
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      c, a
        cp      #8
        jr      c, _legato_post_sign
        sub     #8
        ld      c, a
        ld      a, b
        neg
        ld      b, a
_legato_post_sign:

        ld      LEGATO_TRANSPOSE(ix), b
        ld      LEGATO_DELAY(ix), c

        set     BIT_FX_LEGATO, FX(ix)

        pop     bc

        inc     hl
_legato_end:
        ld      a, #1
        ret


;;; Update the legato state for the current channel
;;; ------
;;;   ix : mirrored state of the current channel
;;;   hl : offset of current note for channel
;;; bc, hl modified
eval_legato_step::

        ld      a, LEGATO_DELAY(ix)
        cp      #0
        jr      z, _legato_update_pos
        dec     LEGATO_DELAY(ix)
        ret
_legato_update_pos:
        ;; hl: current note address
        ;; TODO: make the note offset commong to all track types
        push    ix
        pop     bc
        add     hl, bc

        ;; transpose current note
        ld      a, (hl)
        add     LEGATO_TRANSPOSE(ix)
        ld      (hl), a
        ;; To fully clear the state after the FX is disabled, we must remember
        ;; to recompute the note and tune values without shift, so force it here
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        ;; stop FX
        ld      LEGATO_TRANSPOSE(ix), #0
        res     BIT_FX_LEGATO, FX(ix)

        ret
