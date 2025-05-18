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

;;; Legato functions for FM, SSG, and ADPCM-B
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"



        .area  CODE


;;; Configure the quick legato FX
;;; ------
;;; ;  a  : direction (0:up, 1:down)
;;;   ix  : state for channel
;;; [ hl ]: ticks:4 - transpose:4
;;; hl modified
legato_init::
        push    bc

        ;; b: direction
        ld      b, a

        ;; a: transpose (unsigned)
        ld      a, (hl)
        and     #0xf
        bit     0, b
        jr      z, _legato_post_sign
        neg
_legato_post_sign:
        ld      LEGATO_TRANSPOSE(ix), a

        ;; a: delay before transpose
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      LEGATO_DELAY(ix), a

        set     BIT_FX_LEGATO, NOTE_FX(ix)

        pop     bc
        inc     hl
        ld      a, #1
        ret


;;; Update the legato state for the current channel
;;; ------
;;;   ix : mirrored state of the current channel
eval_legato_step::

        ld      a, LEGATO_DELAY(ix)
        cp      #0
        jr      z, _legato_update_pos
        dec     LEGATO_DELAY(ix)
        ret
_legato_update_pos:
        ;; the shift is the current note position + transpose
        ld      a, NOTE16+1(ix)
        add     LEGATO_TRANSPOSE(ix)
        ld      NOTE16+1(ix), a

        ;; To fully clear the state after the FX is disabled, we must remember
        ;; to recompute the note and tune values without shift, so force it here
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        ;; stop FX
        ld      LEGATO_TRANSPOSE(ix), #0
        res     BIT_FX_LEGATO, NOTE_FX(ix)

        ret


;;; QUICK_LEGATO_UP
;;; Change pitch up by some semitones, after some ticks have passed
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: ticks:4 - transpose:4
;;; hl modified
quick_legato_up::
        ;; a: direction
        xor     a
        jp      legato_init


;;; QUICK_LEGATO_DOWN
;;; Change pitch down by some semitones, after some ticks have passed
;;; ------
;;;   ix  : state for channel
;;; [ hl ]: ticks:4 - transpose:4
;;; hl modified
quick_legato_down::
        ;; a: direction
        xor     a
        jp      legato_init
