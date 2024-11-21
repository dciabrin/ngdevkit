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

;;; Volume slide effect, common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"

        .area  CODE


;;; Enable volume slide effect for the current channel
;;; TODO: handle slide up
;;; ------
;;;   ix  : state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;;   bc  : volume increment
;;;    d  : max volume
;;; [ hl ]: speed (4bits)
;;; [ hl modified ]
vol_slide_init::
        ;; a: speed
        ld      a, (hl)
        inc     hl

        ;; 0 speed means 'disable FX'
        cp      #0
        jr      nz, _setup_vol_slide
        res     BIT_FX_VOL_SLIDE, FX(ix)
        ret
_setup_vol_slide:
        ;; setup FX
        ld      a, #0x40
        ld      VOL_SLIDE_INC16(ix), c
        ld      VOL_SLIDE_INC16+1(ix), b
        ld      a, #0
        ld      VOL_SLIDE_POS16(ix), a
        ld      VOL_SLIDE_POS16+1(ix), a
        ld      a, #15
        ld      VOL_SLIDE_END(ix), d

        ;; enable FX
        set     BIT_FX_VOL_SLIDE, FX(ix)

        ret


;;; Update the volume slide for the current channel by one increment
;;; ------
;;; IN:
;;;   ix: state for the current channel
eval_vol_slide_step::
        push    hl
        push    bc
        ld      l, VOL_SLIDE_POS16(ix)
        ld      h, VOL_SLIDE_POS16+1(ix)
        ld      c, VOL_SLIDE_INC16(ix)
        ld      b, VOL_SLIDE_INC16+1(ix)
        add     hl, bc
        ld      a, h
        cp      VOL_SLIDE_END(ix)
        jr      c, _post_vol_slide_clamp
        ;; the slide FX reached past its end, clamp it
        ld      h, VOL_SLIDE_END(ix)
_post_vol_slide_clamp:
        ld      VOL_SLIDE_POS16(ix), l
        ld      VOL_SLIDE_POS16+1(ix), h
        pop     bc
        pop     hl
        ret
