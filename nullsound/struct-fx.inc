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

        .local  pipeline, fx_fx, fx_trigger, fx_vol_slide, fx_slide, fx_vibrato
        .local  _trigger_action, _trigger_note, _trigger_vol, _trigger_cut, _trigger_delay, _trigger_size
        .local  _vol_slide_inc16, _vol_slide_pos16, _vol_slide_end, _vol_slide_size
        .local  _slide_speed, _slide_depth, _slide_inc16, _slide_pos16, _slide_portamento, _slide_end, _slide_size
        .local _vibrato_speed, _vibrato_depth, _vibrato_pos, _vibrato_pos16, _vibrato_size

;;; actions to run at every tick. This must be the first field of a channel's state
pipeline:               .blkb 1
;;; enabled FX. This must be the second field of a channel's state
fx_fx:                  .blkb 1
fx_trigger:
_trigger_action:        .blkb 1
_trigger_note:          .blkb 1
_trigger_vol:           .blkb 1
_trigger_cut:           .blkb 1
_trigger_delay:         .blkb 1
_trigger_size:
;;; FX: volume slide
fx_vol_slide:
_vol_slide_inc16:       .blkw 1         ; volume slide speed
_vol_slide_pos16:       .blkw 1         ; volume slide position (attenuation)
_vol_slide_end:         .blkb 1         ; volume slide end (0: no attenuation)
_vol_slide_size:
;;; FX: slide
fx_slide:
_slide_speed:           .blkb 1         ; number of increments per tick
_slide_depth:           .blkb 1         ; distance in semitones
_slide_inc16:           .blkw 1         ; 1/8 semitone increment * speed
_slide_pos16:           .blkw 1         ; slide pos
_slide_end:             .blkb 1         ; end note (octave/semitone)
_slide_portamento:      .blkb 1         ; portamento to target note
_slide_size:
;;; FX: vibrato
fx_vibrato:
_vibrato_speed:         .blkb 1         ; vibrato_speed
_vibrato_depth:         .blkb 1         ; vibrato_depth
_vibrato_pos:           .blkb 1         ; vibrato_pos
_vibrato_pos16:         .blkw 1         ; vibrato_pos16
_vibrato_size:

        ;; FX getter for a channel's state
        ;; The offset assumes that that the FX structure are located
        ;; sequentially from the start of the channel's state
        .lclequ PIPELINE,       (pipeline - pipeline)
        .lclequ FX,             (fx_fx - pipeline)
        .lclequ TRIGGER,        (fx_trigger - pipeline)
        .lclequ TRIGGER_ACTION, (_trigger_action - pipeline)
        .lclequ TRIGGER_NOTE,   (_trigger_note - pipeline)
        .lclequ TRIGGER_VOL,    (_trigger_vol - pipeline)
        .lclequ TRIGGER_CUT,    (_trigger_cut - pipeline)
        .lclequ TRIGGER_DELAY,  (_trigger_delay - pipeline)
        .lclequ TRIGGER_SIZE,   (_trigger_size - fx_trigger)
        .lclequ VOL_SLIDE,      (fx_vol_slide - pipeline)
        .lclequ VOL_SLIDE_INC16, (_vol_slide_inc16 - pipeline)
        .lclequ VOL_SLIDE_POS16, (_vol_slide_pos16 - pipeline)
        .lclequ VOL_SLIDE_END,  (_vol_slide_end - pipeline)
        .lclequ VOL_SLIDE_SIZE, (_vol_slide_size - fx_vol_slide)
        .lclequ SLIDE,          (fx_slide - pipeline)
        .lclequ SLIDE_SPEED,    (_slide_speed - pipeline)
        .lclequ SLIDE_DEPTH,    (_slide_depth - pipeline)
        .lclequ SLIDE_INC16,    (_slide_inc16 - pipeline)
        .lclequ SLIDE_POS16,    (_slide_pos16 - pipeline)
        .lclequ SLIDE_PORTAMENTO, (_slide_portamento - pipeline)
        .lclequ SLIDE_END,      (_slide_end - pipeline)
        .lclequ SLIDE_SIZE,     (_slide_size - fx_slide)
        .lclequ VIBRATO,        (fx_vibrato - pipeline)
        .lclequ VIBRATO_SPEED,  (_vibrato_speed - pipeline)
        .lclequ VIBRATO_DEPTH,  (_vibrato_depth - pipeline)
        .lclequ VIBRATO_POS,    (_vibrato_pos - pipeline)
        .lclequ VIBRATO_POS16,  (_vibrato_pos16 - pipeline)
        .lclequ VIBRATO_SIZE,   (_vibrato_size - fx_vibrato)

        .lclequ BIT_FX_VIBRATO,         0
        .lclequ BIT_FX_SLIDE,           1
        .lclequ BIT_FX_VOL_SLIDE,       2
        .lclequ BIT_FX_TRIGGER,         3

        .lclequ TRIGGER_LOAD_NOTE_FUNC,         0
        .lclequ TRIGGER_LOAD_VOL_FUNC,          2
        .lclequ TRIGGER_STOP_NOTE_FUNC,         4

        .lclequ BIT_TRIGGER_ACTION_DELAY,       0
        .lclequ BIT_TRIGGER_ACTION_CUT,         1
        .lclequ BIT_TRIGGER_LOAD_NOTE,          4
        .lclequ BIT_TRIGGER_LOAD_VOL,           5
