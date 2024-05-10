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

;;; FX structures for channels
;;;

        ;; We define structures by creating local labels that point to
        ;; memory allocated in a special area that does not get linked.
        ;; This way we can generate getter macros and include this
        ;; file many times without linking errors.

        .area   struct

        .local  fx_fx, fx_slide, fx_vibrato
        .local  _slide_speed, _slide_depth, _slide_inc16, _slide_pos16, _slide_end, _slide_size
        .local _vibrato_speed, _vibrato_depth, _vibrato_pos, _vibrato_prev, _vibrato_next, _vibrato_size

;;; enabled FX. This must be the first field of a channel's state
fx_fx:                  .blkb 1
;;; FX: slide
fx_slide:
_slide_speed:           .blkb 1         ; number of increments per tick
_slide_depth:           .blkb 1         ; distance in semitones
_slide_inc16:           .blkw 1         ; 1/8 semitone increment * speed
_slide_pos16:           .blkw 1         ; slide pos
_slide_end:             .blkb 1         ; end note (octave/semitone)
_slide_size:
;;; FX: vibrato
fx_vibrato:
_vibrato_speed:         .blkb 1         ; vibrato_speed
_vibrato_depth:         .blkb 1         ; vibrato_depth
_vibrato_pos:           .blkb 1         ; vibrato_pos
_vibrato_prev:          .blkw 1         ; vibrato_prev
_vibrato_next:          .blkw 1         ; vibrato_next
_vibrato_size:

        ;; FX getter for a channel's state
        ;; The offset assumes that that the FX structure are located
        ;; sequentially from the start of the channel's state
        .lclequ VIBRATO,        (fx_vibrato - fx_fx)
        .lclequ VIBRATO_SPEED,  (_vibrato_speed - fx_fx)
        .lclequ VIBRATO_DEPTH,  (_vibrato_depth - fx_fx)
        .lclequ VIBRATO_POS,    (_vibrato_pos - fx_fx)
        .lclequ VIBRATO_PREV,   (_vibrato_prev - fx_fx)
        .lclequ VIBRATO_NEXT,   (_vibrato_next - fx_fx)
        .lclequ VIBRATO_SIZE,   (_vibrato_size - fx_vibrato)
