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
        .local  _data_ctx, _data_fx, _data_cfg, _data16
        .local  pipeline
        .local  fx_fx, cfg_vol, vol16, fx_vol_slide
        .local  note_fx, cfg_note, note16, fx_note_slide, fx_vibrato, fx_arpeggio, fx_legato
        .local  _trigger, _trigger_action, _trigger_note, _trigger_vol, _trigger_arg, _trigger_cur, _trigger_size
        .local  _vol_slide, _vol_slide_cfg, _vol_slide_inc16, _vol_slide_end, _vol_slide_max, _vol_slide_size
        .local  _vibrato, _vibrato_speed, _vibrato_depth, _vibrato_pos, _vibrato_pos16, _vibrato_size
        .local  _arpeggio, _arpeggio_speed, _arpeggio_count, _arpeggio_2nd, _arpeggio_3rd, _arpeggio_pos, _arpeggio_pos8, _arpeggio_size
        .local  _legato, _legato_cfg, _legato_delay, _legato_transpose, _legato_size
        .local  fx_trigger


;;; The pipeline structure holds properties and state trackers common to all channels
;;; fields before field `pipeline` are optional based on the type of channel

;;; optional note and FX state tracker
note_fx:                .blkb 1         ; enabled note FX
cfg_note:               .blkb 1         ; configured note
note16:                 .blkb 2         ; current decimal note
fx_note_slide:          .blkb SLIDE_SIZE
fx_vibrato:             .blkb VIBRATO_SIZE
fx_arpeggio:            .blkb ARPEGGIO_SIZE
fx_legato:              .blkb LEGATO_SIZE
;;; strean pipeline
pipeline:               .blkb 1         ; actions to run at every tick (load note, vol, other regs)
fx_fx:                  .blkb 1         ; enabled FX. This must be the second field of a channel's state
;;; volume state tracker
cfg_vol:                .blkb 1         ; configured volume
vol16:                  .blkb 2         ; current decimal volume
;;; misc fx state tracker
fx_vol_slide:           .blkb SLIDE_SIZE
fx_trigger:             .blkb TRIGGER_SIZE


;;; common FX for note and volume are prefix with those common fields
_data_ctx:
_data_fx:                .blkb 1         ; enabled FX for this data
_data_cfg:               .blkb 1         ; configured data
_data16:                 .blkb 2         ; current decimal data

;;; FX: slide
_vol_slide:
_vol_slide_cfg:         .blkb 1         ; config (up, down, portamento)
_vol_slide_inc16:       .blkw 1         ; volume slide speed
_vol_slide_end:         .blkw 1         ; volume slide end
_vol_slide_max:         .blkb 1         ; volume slide max for channel
_vol_slide_size:

;;; FX: vibrato
_vibrato:
_vibrato_speed:         .blkb 1         ; vibrato_speed
_vibrato_depth:         .blkb 1         ; vibrato_depth
_vibrato_pos:           .blkb 1         ; vibrato_pos
_vibrato_pos16:         .blkw 1         ; vibrato_pos16
_vibrato_size:

;;; FX: arpeggio
_arpeggio:
_arpeggio_speed:        .blkb 1         ; number of ticks between notes
_arpeggio_count:        .blkb 1         ; countdown before next tick
_arpeggio_2nd:          .blkb 1         ; 2nd note offset in the chord
_arpeggio_3rd:          .blkb 1         ; 3rd note offset in the chord
_arpeggio_pos:          .blkb 1         ; position in arpeggio [0, 2, 1]
_arpeggio_pos8:         .blkb 1         ; current note offset
_arpeggio_size:

;;; FX: legato
_legato:
_legato_cfg:            .blkb 1         ; config (up, down...)
_legato_delay:          .blkb 1         ; number of ticks before new note
_legato_transpose:      .blkb 1         ; transpose note in semitone (signed)
_legato_size:

;;; FX: trigger
_trigger:
_trigger_action:        .blkb 1         ; trigger action (cut, delay, retrigger)
_trigger_note:          .blkb 1         ; trigger delayed note
_trigger_vol:           .blkb 1         ; trigger delayed volume
_trigger_arg:           .blkb 1         ; per-action argument
_trigger_cur:           .blkb 1         ; per-action current accumulator
_trigger_size:


        ;; FX getter for a channel's state
        ;; The offset assumes that that the FX structure are located
        ;; at the same location in reference to the pipeline field,
        ;; and they are the same for all channels
        .lclequ PIPELINE,       (pipeline - pipeline)
        .lclequ FX,             (fx_fx - pipeline)
        ;; note and volume can both have a slide a vibrato/tremolo FX, so their
        ;; attribute share the same alignement in memory.
        .lclequ VOL_CTX,            FX
        .lclequ VOL,                (cfg_vol - pipeline)
        .lclequ VOL16,              (vol16   - pipeline)
        .lclequ NOTE_CTX,           NOTE_FX
        .lclequ NOTE_FX,            (note_fx  - pipeline)
        .lclequ NOTE,               (cfg_note - pipeline)
        .lclequ NOTE16,             (note16   - pipeline)
        ;; getter for accessing the pipeline from the start of a FM, SSG, ADPCM-B
        .lclequ PIPELINE_FROM_NOTE, (pipeline - note_fx)

        ;; FX that are common to the volume and note properties have getters
        ;; relative to the propertie. they are accessed with register iy
        .lclequ DATA_FX,             (_data_fx  - _data_ctx)
        .lclequ DATA_CFG,            (_data_cfg - _data_ctx)
        .lclequ DATA16,              (_data16   - _data_ctx)
        ;; FX slide
        .lclequ SLIDE_CFG,  (_vol_slide_cfg    - _data_ctx)
        .lclequ SLIDE_INC16, (_vol_slide_inc16 - _data_ctx)
        .lclequ SLIDE_END,  (_vol_slide_end    - _data_ctx)
        .lclequ SLIDE_MAX,  (_vol_slide_max    - _data_ctx)
        .lclequ SLIDE_SIZE, (_vol_slide_size   - _vol_slide)
        ;; FX vibrato/tremolo
        .lclequ VIBRATO_SPEED,  (_vibrato_speed - _data_ctx)
        .lclequ VIBRATO_DEPTH,  (_vibrato_depth - _data_ctx)
        .lclequ VIBRATO_POS,    (_vibrato_pos   - _data_ctx)
        .lclequ VIBRATO_POS16,  (_vibrato_pos16 - _data_ctx)
        .lclequ VIBRATO_SIZE,   (_vibrato_size  - _vibrato)

        ;; other FX are relative to the pipeline field, so they can be
        ;; addressed directly as an offset from register ix
        ;; FX arpeggio
        .lclequ ARPEGGIO_SPEED, (_arpeggio_speed - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_COUNT, (_arpeggio_count - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_2ND,   (_arpeggio_2nd   - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_3RD,   (_arpeggio_3rd   - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_POS,   (_arpeggio_pos   - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_POS8,  (_arpeggio_pos8  - _arpeggio + fx_arpeggio - pipeline)
        .lclequ ARPEGGIO_SIZE,  (_arpeggio_size  - _arpeggio)
        ;; FX legato
        .lclequ LEGATO_CFG,       (_legato_cfg       - _legato + fx_legato - pipeline)
        .lclequ LEGATO_DELAY,     (_legato_delay     - _legato + fx_legato - pipeline)
        .lclequ LEGATO_TRANSPOSE, (_legato_transpose - _legato + fx_legato - pipeline)
        .lclequ LEGATO_SIZE,      (_legato_size      - _legato)
        ;; FX trigger
        .lclequ TRIGGER_ACTION, (_trigger_action - _trigger + fx_trigger - pipeline)
        .lclequ TRIGGER_NOTE,   (_trigger_note   - _trigger + fx_trigger - pipeline)
        .lclequ TRIGGER_VOL,    (_trigger_vol    - _trigger + fx_trigger - pipeline)
        .lclequ TRIGGER_ARG,    (_trigger_arg    - _trigger + fx_trigger - pipeline)
        .lclequ TRIGGER_CUR,    (_trigger_cur    - _trigger + fx_trigger - pipeline)
        .lclequ TRIGGER_SIZE,   (_trigger_size   - _trigger)

        ;; Enabled FX
        .lclequ BIT_FX_TRIGGER,         0
        .lclequ BIT_FX_SLIDE,           1
        .lclequ BIT_FX_VIBRATO,         2
        .lclequ BIT_FX_ARPEGGIO,        3
        .lclequ BIT_FX_LEGATO,          4

        ;; Trigger FX function interface
        .lclequ TRIGGER_LOAD_NOTE_FUNC,         0
        .lclequ TRIGGER_LOAD_VOL_FUNC,          2
        .lclequ TRIGGER_STOP_NOTE_FUNC,         4
        ;; Trigger FX configuration
        .lclequ BIT_TRIGGER_ACTION_DELAY,       0
        .lclequ BIT_TRIGGER_ACTION_CUT,         1
        .lclequ BIT_TRIGGER_ACTION_RETRIGGER,   2
        .lclequ BIT_TRIGGER_LOAD_NOTE,          4
        .lclequ BIT_TRIGGER_LOAD_VOL,           5

        ;; Slide FX configuration
        .lclequ BIT_SLIDE_DIRECTION,            0
        .lclequ BIT_SLIDE_PORTAMENTO,           1
        .lclequ BIT_SLIDE_KEEP_RUNNING,         2
