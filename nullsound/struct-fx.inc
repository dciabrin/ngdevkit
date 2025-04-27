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

        .local  pipeline, fx_fx, fx_trigger, fx_vol_slide, fx_slide, fx_vibrato, fx_arpeggio
        .local  _trigger_action, _trigger_note, _trigger_vol, _trigger_arg, _trigger_cur, _trigger_size
        .local  _vol_slide_inc16, _vol_slide_pos16, _vol_slide_end, _vol_slide_size
        .local  _slide_cfg, _slide_inc16, _slide_pos16, _slide_end, _slide_size
        .local _vibrato_speed, _vibrato_depth, _vibrato_pos, _vibrato_pos16, _vibrato_size
        .local _arpeggio_speed, _arpeggio_count, _arpeggio_2nd, _arpeggio_3rd, _arpeggio_pos, _arpeggio_pos8, _arpeggio_size

;;; actions to run at every tick. This must be the first field of a channel's state
pipeline:               .blkb 1
;;; enabled FX. This must be the second field of a channel's state
fx_fx:                  .blkb 1
fx_trigger:
_trigger_action:        .blkb 1         ; trigger action (cut, delay, retrigger)
_trigger_note:          .blkb 1         ; trigger delayed note
_trigger_vol:           .blkb 1         ; trigger delayed volume
_trigger_arg:           .blkb 1         ; per-action argument
_trigger_cur:           .blkb 1         ; per-action current accumulator
_trigger_size:
;;; FX: volume slide
fx_vol_slide:
_vol_slide_inc16:       .blkw 1         ; volume slide speed
_vol_slide_pos16:       .blkw 1         ; volume slide position (attenuation)
_vol_slide_end:         .blkb 1         ; volume slide end (0: no attenuation)
_vol_slide_size:
;;; FX: slide
fx_slide:
_slide_cfg:             .blkb 1         ; config (up, down, portamento)
_slide_inc16:           .blkw 1         ; semitone increment * speed
_slide_pos16:           .blkw 1         ; slide pos
_slide_end:             .blkb 1         ; target note
_slide_size:
;;; FX: vibrato
fx_vibrato:
_vibrato_speed:         .blkb 1         ; vibrato_speed
_vibrato_depth:         .blkb 1         ; vibrato_depth
_vibrato_pos:           .blkb 1         ; vibrato_pos
_vibrato_pos16:         .blkw 1         ; vibrato_pos16
_vibrato_size:
;;; FX: arpeggio
fx_arpeggio:
_arpeggio_speed:        .blkb 1         ; number of ticks between notes
_arpeggio_count:        .blkb 1         ; countdown before next tick
_arpeggio_2nd:          .blkb 1         ; 2nd note offset in the chord
_arpeggio_3rd:          .blkb 1         ; 3rd note offset in the chord
_arpeggio_pos:          .blkb 1         ; position in arpeggio [0, 2, 1]
_arpeggio_pos8:         .blkb 1         ; current note offset
_arpeggio_size:

        ;; FX getter for a channel's state
        ;; The offset assumes that that the FX structure are located
        ;; sequentially from the start of the channel's state
        .lclequ PIPELINE,       (pipeline - pipeline)
        .lclequ FX,             (fx_fx - pipeline)
        .lclequ TRIGGER,        (fx_trigger - pipeline)
        .lclequ TRIGGER_ACTION, (_trigger_action - pipeline)
        .lclequ TRIGGER_NOTE,   (_trigger_note - pipeline)
        .lclequ TRIGGER_VOL,    (_trigger_vol - pipeline)
        .lclequ TRIGGER_ARG,    (_trigger_arg - pipeline)
        .lclequ TRIGGER_CUR,    (_trigger_cur - pipeline)
        .lclequ TRIGGER_SIZE,   (_trigger_size - fx_trigger)
        .lclequ VOL_SLIDE,      (fx_vol_slide - pipeline)
        .lclequ VOL_SLIDE_INC16, (_vol_slide_inc16 - pipeline)
        .lclequ VOL_SLIDE_POS16, (_vol_slide_pos16 - pipeline)
        .lclequ VOL_SLIDE_END,  (_vol_slide_end - pipeline)
        .lclequ VOL_SLIDE_SIZE, (_vol_slide_size - fx_vol_slide)
        .lclequ SLIDE,          (fx_slide - pipeline)
        .lclequ SLIDE_CFG,      (_slide_cfg - pipeline)
        .lclequ SLIDE_INC16,    (_slide_inc16 - pipeline)
        .lclequ SLIDE_POS16,    (_slide_pos16 - pipeline)
        .lclequ SLIDE_END,      (_slide_end - pipeline)
        .lclequ SLIDE_SIZE,     (_slide_size - fx_slide)
        .lclequ VIBRATO,        (fx_vibrato - pipeline)
        .lclequ VIBRATO_SPEED,  (_vibrato_speed - pipeline)
        .lclequ VIBRATO_DEPTH,  (_vibrato_depth - pipeline)
        .lclequ VIBRATO_POS,    (_vibrato_pos - pipeline)
        .lclequ VIBRATO_POS16,  (_vibrato_pos16 - pipeline)
        .lclequ VIBRATO_SIZE,   (_vibrato_size - fx_vibrato)
        .lclequ ARPEGGIO,       (fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_SPEED, (_arpeggio_speed - pipeline)
        .lclequ ARPEGGIO_COUNT, (_arpeggio_count - pipeline)
        .lclequ ARPEGGIO_2ND,   (_arpeggio_2nd - pipeline)
        .lclequ ARPEGGIO_3RD,   (_arpeggio_3rd - pipeline)
        .lclequ ARPEGGIO_POS,   (_arpeggio_pos - pipeline)
        .lclequ ARPEGGIO_POS8,  (_arpeggio_pos8 - pipeline)
        .lclequ ARPEGGIO_SIZE,  (_arpeggio_size - fx_arpeggio)

        .lclequ BIT_FX_VIBRATO,         0
        .lclequ BIT_FX_SLIDE,           1
        .lclequ BIT_FX_VOL_SLIDE,       2
        .lclequ BIT_FX_TRIGGER,         3
        .lclequ BIT_FX_ARPEGGIO,        4

        .lclequ TRIGGER_LOAD_NOTE_FUNC,         0
        .lclequ TRIGGER_LOAD_VOL_FUNC,          2
        .lclequ TRIGGER_STOP_NOTE_FUNC,         4

        .lclequ BIT_TRIGGER_ACTION_DELAY,       0
        .lclequ BIT_TRIGGER_ACTION_CUT,         1
        .lclequ BIT_TRIGGER_ACTION_RETRIGGER,   2
        .lclequ BIT_TRIGGER_LOAD_NOTE,          4
        .lclequ BIT_TRIGGER_LOAD_VOL,           5

        .lclequ BIT_SLIDE_DIRECTION,            0
        .lclequ BIT_SLIDE_PORTAMENTO,           1
