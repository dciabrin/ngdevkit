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

;;; Volume slide effect, common functions for FM and SSG
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"

        .area  CODE


;;; Setup the fixed-point increment for the slide
;;; ------
;;;    c  : increment size (increment = 1/2^c)
;;;    e  : speed (increments)
;;; bc, de modified
vol_slide_init_increment::

        ;; de: inc16 = speed / 2^c
        ld      d, e
        ld      e, #0
__vol_slide_divide:
        srl     d
        rr      e
        dec     c
        jr      nz, __vol_slide_divide

        ;; store absolute speed (no direction)
        ld      VOL_SLIDE_INC16(ix), e
        ld      VOL_SLIDE_INC16+1(ix), d

        ret


;;; Initialize the source volume for the slide
;;; ------
;;;   ix  : state for channel
;;;    b  : current volume
vol_slide_init_source::
        ;; init slide position if no volume slide FX is ongoing
        bit     BIT_FX_VOL_SLIDE, FX(ix)
        jr      nz, _vol_post_init_slide
        ld      VOL_SLIDE_POS16(ix), #0
        ld      VOL_SLIDE_POS16+1(ix), b
_vol_post_init_slide:
        ret


;;; Initialize a target volume for the slide
;;; ------
;;;   ix  : state for channel
;;;    b  : current volume
;;;    d  : target offset (signed)
vol_slide_init_target::
        ;; init slide direction
        res     BIT_SLIDE_DIRECTION, VOL_SLIDE_CFG(ix)

        ;; slide target is the current position + new displacement
        ;; a: target note
        ld      a, b
        add     d
        ;; down: we also need to go one seminote below, to account
        ;; for the fractional parts of the slide.
        bit     7, d
        jr      z, _post_neg_vol_slide
        set     BIT_SLIDE_DIRECTION, VOL_SLIDE_CFG(ix)
        dec     a
_post_neg_vol_slide:
        ld      VOL_SLIDE_END(ix), a

        ret


;;; Increment current fixed point displacement and
;;; stop effects when the target displacement is reached
;;; ------
;;; IN:
;;;   ix : state for channel
;;; bc, de, hl modified
eval_vol_slide_step:
        ;; bc: increment
        ld      c, VOL_SLIDE_INC16(ix)
        ld      b, VOL_SLIDE_INC16+1(ix)
        ;; hl: decimal note (FX copy)
        ld      l, VOL_SLIDE_POS16(ix)
        ld      h, VOL_SLIDE_POS16+1(ix)

        ;; c: 0 slide up, 1 slide down
        bit     BIT_SLIDE_DIRECTION, VOL_SLIDE_CFG(ix)
        jr      nz, _vol_slide_sub_inc

_vol_slide_add_inc:
        ;; de: pos16+inc16
        add     hl, bc
        ex      de, hl
        ;; bc: 00xx (end vol)
        ld      c, VOL_SLIDE_END(ix)
        ld      b, VOL_SLIDE_END+1(ix)
        ;; lh: new pos16 MSB
        ld      l, d
        ld      h, #0
        jr      _vol_slide_cp
_vol_slide_sub_inc:
        ;; de: pos16-inc16
        or      a
        sbc     hl, bc
        ex      de, hl
        ;; bc: new pos16 MSB
        ld      c, d
        ld      b, #0
        ;; lh: 00xx (end vol) or ffff (-1)
        ld      l, VOL_SLIDE_END(ix)
        ld      h, VOL_SLIDE_END+1(ix)

        ;; have we reached the end of the slide?
        ;; slide up:   continue if cur < end
        ;; slide down: continue if end < cur
        ;; note: we don't check for equality because the increment
        ;; can go past the target note
_vol_slide_cp:
        or      a
        sbc     hl, bc
        jp      m, _vol_slide_intermediate

        ;; slide has reached its target

        ;; hl: clamp the last slide pos to the target displacement
        ld      h, VOL_SLIDE_END(ix)
        ld      l, #0

        ;; for slide down, we finish one note below the real target to play
        ;; all ticks with fractional parts. Adjust the end displacement back if needed
        bit     BIT_SLIDE_DIRECTION, VOL_SLIDE_CFG(ix)
        jr      z, _vol_slide_post_sub_clamp
        inc     h
_vol_slide_post_sub_clamp:
        ;; slide is finished, but only stop the effect if requested
        bit     BIT_SLIDE_KEEP_RUNNING, VOL_SLIDE_CFG(ix)
        jr      nz, _vol_slide_intermediate
        res     BIT_FX_VOL_SLIDE, FX(ix)

_vol_slide_intermediate:
        ;; effect is still running
        ;; CHECK: when we stop the slide midway, we can only keep the
        ;; integer part of the slide, which may not match Furnace's semantics
        ld      VOL_SLIDE_POS16(ix), e
        ld      VOL_SLIDE_POS16+1(ix), d
        ld      VOL(ix), d

        ret


;;; Enable volume slide effect for the current channel
;;; ------
;;;   ix  : state for channel
;;;    a  : slide direction: 0 == up, 1 == down
;;; [ hl ]: increment
vol_slide_init::
        ;; FX configuration
        ld      VOL_SLIDE_CFG(ix), a

        push    bc
        push    de

        ;; e: increment
        ld      e, (hl)
        inc     hl
        push    hl

        ;; c: increment size: 1/4 volume
        ld      c, #2
        call    vol_slide_init_increment

        ;; b: current volume
        ld      b, VOL(ix)

        ;; init volume slide source (absolute value)
        call    vol_slide_init_source

        ;; set up a default target bound, as per definition, vol slides
        ;; do not have one (they rely on the stop FX in the music)
        ld      bc, #-1
        bit     BIT_SLIDE_DIRECTION, VOL_SLIDE_CFG(ix)
        jr      nz, _vol_slide_init_direction
        ld      b, #0
        ld      c, VOL_SLIDE_MAX(ix)
_vol_slide_init_direction:
        ld      VOL_SLIDE_END(ix), c
        ld      VOL_SLIDE_END+1(ix), b
        set     BIT_FX_VOL_SLIDE, FX(ix)

        pop     hl
        pop     de
        pop     bc

        ld      a, #1
        ret


;;; Update an ongoing volume slide effect with a new volume
;;; ------
;;;   ix  : state for channel
;;;     a : new volume for channel
vol_slide_update::
        bit     BIT_SLIDE_PORTAMENTO, VOL_SLIDE_CFG(ix)
        jr      nz, _vol_slide_update_target

_vol_slide_update_src:
        ld      VOL_SLIDE_POS16(ix), #0
        ld      VOL_SLIDE_POS16+1(ix), a
        ret

_vol_slide_update_target:
        ;; b: current volume
        ld      b, a
        ;; d: displacement (new vol - current vol)
        sub     VOL(ix)
        ld      d, a
        call    vol_slide_init_target
        ret


;;; VOL_SLIDE_OFF
;;; Stop the volume slide effect in progress for the current channel
;;; ------
vol_slide_off::
        ;; set the new volume from current slide position
        ld      a, VOL_SLIDE_POS16+1(ix)
        ld      VOL(ix), a
        ;; since we disable the FX outside of the pipeline process
        ;; make sure to load this new volume at next pipeline run
        res     BIT_FX_VOL_SLIDE, FX(ix)
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; VOL_SLIDE_UP
;;; Enable volume slide up effect for the current channel
;;; ------
;;; [ hl ]: increment
vol_slide_up::
        ld      a, #0
        set     BIT_SLIDE_KEEP_RUNNING, a
        jp      vol_slide_init


;;; VOL_SLIDE_DOWN
;;; Enable volume slide down effect for the current channel
;;; ------
;;; [ hl ]: increment
vol_slide_down::
        ld      a, #1
        set     BIT_SLIDE_KEEP_RUNNING, a
        jp      vol_slide_init
