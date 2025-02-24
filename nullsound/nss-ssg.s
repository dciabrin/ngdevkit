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

;;; NSS opcode for SSG channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .lclequ SSG_STATE_SIZE,(state_mirrored_ssg_end-state_mirrored_ssg)
        ;; .lclequ PIPELINE,(state_ssg_pipeline-state_mirrored_ssg)

        ;; getters for SSG state
        .lclequ NOTE,(state_ssg_note-state_mirrored_ssg)
        .lclequ DETUNE,(state_ssg_detune-state_mirrored_ssg)
        .lclequ NOTE_POS16,(state_ssg_note_pos16-state_mirrored_ssg)
        .lclequ NOTE_FINE_COARSE,(state_ssg_note_fine_coarse-state_mirrored_ssg)
        .lclequ PROPS_OFFSET,(state_mirrored_ssg_props-state_mirrored_ssg)
        .lclequ ENVELOPE_OFFSET,(state_mirrored_ssg_envelope-state_mirrored_ssg)
        .lclequ WAVEFORM_OFFSET,(state_mirrored_ssg_waveform-state_mirrored_ssg)
        .lclequ ARPEGGIO,(state_ssg_arpeggio-state_mirrored_ssg)
        .lclequ MACRO_DATA,(state_ssg_macro_data-state_mirrored_ssg)
        .lclequ MACRO_POS,(state_ssg_macro_pos-state_mirrored_ssg)
        .lclequ MACRO_LOAD,(state_ssg_macro_load-state_mirrored_ssg)
        .lclequ REG_VOL, (state_ssg_reg_vol-state_mirrored_ssg)
        .lclequ VOL, (state_ssg_vol-state_mirrored_ssg)
        .lclequ OUT_VOL, (state_ssg_out_vol-state_mirrored_ssg)

        ;; pipeline state for SSG channel
        .lclequ STATE_PLAYING,          0x01
        .lclequ STATE_EVAL_MACRO,       0x02
        .lclequ STATE_LOAD_NOTE,        0x04
        .lclequ STATE_LOAD_WAVEFORM,    0x08
        .lclequ STATE_LOAD_VOL,         0x10
        .lclequ STATE_LOAD_REGS,        0x20
        .lclequ STATE_STOP_NOTE,        0x40
        .lclequ STATE_NOTE_STARTED,     0x80
        .lclequ BIT_PLAYING,            0
        .lclequ BIT_EVAL_MACRO,         1
        .lclequ BIT_LOAD_NOTE,          2
        .lclequ BIT_LOAD_WAVEFORM,      3
        .lclequ BIT_LOAD_VOL,           4
        .lclequ BIT_LOAD_REGS,          5
        .lclequ BIT_STOP_NOTE,          6
        .lclequ BIT_NOTE_STARTED,       7


        .area  DATA

;;; SSG playback state tracker
;;; ------
        ;; This padding ensures the entire _state_ssg data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   110

;;; SSG tune table in use (MVS or AES)
state_ssg_tune::
        .blkw   1

;;; SSG half-distance table in use (MVS or AES)
state_ssg_semitone_distance::
        .blkw   1

_state_ssg_start:

;;; context: current SSG channel for opcode actions
state_ssg_channel::
        .blkb   1

;;; YM2610 mirrored state
;;; ------
;;; used to compute final register values to be loaded into the YM2610

;;; merged waveforms of all SSG channels for REG_SSG_ENABLE
state_mirrored_enabled:
        .blkb   1

;;; ssg mirrored state
state_mirrored_ssg:
;;; SSG A
state_mirrored_ssg_a:
state_ssg_pipeline:             .blkb   1       ; actions to run at every tick (eval macro, load note, vol, other regs)
state_ssg_fx:                   .blkb   1       ; enabled FX for this channel
;;; FX state trackers
state_ssg_trigger:              .blkb   TRIGGER_SIZE
state_ssg_fx_vol_slide:         .blkb   VOL_SLIDE_SIZE
state_ssg_fx_slide:             .blkb   SLIDE_SIZE
state_ssg_fx_vibrato:           .blkb   VIBRATO_SIZE
;;; SSG-specific state
;;; Note
state_ssg_note_pos16:           .blkb   2       ; fixed-point note after the FX pipeline
state_ssg_note:                 .blkb   1       ; NSS note to be played on the FM channel
state_ssg_detune:               .blkb   2       ; fixed-point semitone detune
state_ssg_note_fine_coarse:     .blkb   2       ; YM2610 note factors (fine+coarse)
state_mirrored_ssg_props:
state_mirrored_ssg_envelope:    .blkb   1       ; envelope shape
                                .blkb   1       ; vol envelope fine
                                .blkb   1       ; vol envelope coarse
state_ssg_reg_vol:              .blkb   1       ; mode+volume
state_mirrored_ssg_waveform:    .blkb   1       ; noise+tone (shifted per channel)
state_ssg_arpeggio:             .blkb   1       ; arpeggio (semitone shift)
state_ssg_macro_data:           .blkb   2       ; address of the start of the macro program
state_ssg_macro_pos:            .blkb   2       ; address of the current position in the macro program
state_ssg_macro_load:           .blkb   2       ; function to load the SSG registers modified by the macro program
state_ssg_vol:                  .blkb   1       ; note volume (attenuation)
state_ssg_out_vol:              .blkb   1       ; ym2610 volume for SSG channel after the FX pipeline
state_mirrored_ssg_end:
;;; SSG B
state_mirrored_ssg_b:
        .blkb   SSG_STATE_SIZE
;;; SSG C
state_mirrored_ssg_c:
        .blkb   SSG_STATE_SIZE

;;; Global volume attenuation for all SSG channels
state_ssg_volume_attenuation::       .blkb   1

_state_ssg_end:

        .area  CODE


;;; context: channel action functions for SSG
state_ssg_action_funcs:
        .dw     ssg_configure_note_on
        .dw     ssg_configure_vol
        .dw     ssg_stop_playback


;;;  Reset SSG playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_ssg_state_tracker::
        ld      hl, #_state_ssg_start
        ld      d, h
        ld      e, l
        inc     de
        ld      (hl), #0
        ld      bc, #_state_ssg_end-2-_state_ssg_start
        ldir
        ;; global SSG volume is initialized in the volume state tracker
        ld      a, #0x3f
        ld      (state_mirrored_enabled), a
        ;; set up current tune and half distance tables
        ld      bc, #ssg_tune_aes
        ld      (state_ssg_tune), bc
        ld      bc, #ssg_semitone_distance_aes
        ld      (state_ssg_semitone_distance), bc
        ret


;;;
;;; Macro instrument - internal functions
;;;

;;; eval_macro_step
;;; update the mirror state for a SSG channel based on
;;; the macro program configured for this channel
;;; ------
;;; bc, de, hl modified
eval_macro_step::
        ;; de: state_mirrored_ssg_props (8bit add)
        push    ix
        pop     de
        ld      a, e
        add     #PROPS_OFFSET
        ld      e, a

        ;; hl: macro location ptr
        ld      l, MACRO_POS(ix)
        ld      h, MACRO_POS+1(ix)

        ;; update mirrored state with macro values
        ld      a, (hl)
        inc     hl
_upd_macro:
        cp      a, #0xff
        jp      z, _end_upd_macro
        ;; de: next offset in mirrored state (8bit add)
        add     a, e
        ld      e, a
        ;; (de): (hl)
        ldi
        ld      a, (hl)
        inc     hl
        jp      _upd_macro
_end_upd_macro:
        ;; update load flags for this macro step
        ld      a, PIPELINE(ix)
        or      (hl)
        inc     hl
        ld      PIPELINE(ix), a
        ;; did we reached the end of macro
        ld      a, (hl)
        cp      a, #0xff
        jp      nz, _finish_macro_step
        ;; end of macro, set loop/no-loop information
        ;; the load bits have been set in the previous step
        inc     hl
        ld      a, (hl)
        ld      MACRO_POS(ix), a
        inc     hl
        ld      a, (hl)
        ld      MACRO_POS+1(ix), a
        ret
_finish_macro_step:
        ;; keep track of the current location for the next call
        ld      MACRO_POS(ix), l
        ld      MACRO_POS+1(ix), h
        ret


;;; Set the current SSG channel and SSG state context
;;; ------
;;;   a : SSG channel
ssg_ctx_set_current::
        ld      (state_ssg_channel), a
        ld      ix, #state_mirrored_ssg
        push    bc
        bit     0, a
        jr      z, _ssg_ctx_post_bit0
        ld      bc, #SSG_STATE_SIZE
        add     ix, bc
_ssg_ctx_post_bit0:
        bit     1, a
        jr      z, _ssg_ctx_post_bit1
        ld      bc, #SSG_STATE_SIZE*2
        add     ix, bc
_ssg_ctx_post_bit1:
        pop     bc
        ret


;;; run_ssg_pipeline
;;; ------
;;; Run the entire SSG pipeline once. for each SSG channels:
;;;  - run a single round of macro steps configured
;;;  - update the state of all enabled FX
;;;  - load specific parts of the state (note, vol...) into YM2610 registers
;;; Meant to run once per tick
run_ssg_pipeline::
        push    de
        ;; TODO should we consider IX and IY scratch registers?
        push    iy
        push    ix

        ;; we loop though every channel during the execution,
        ;; so save the current channel context
        ld      a, (state_ssg_channel)
        push    af

        ;; update mirrored state of all SSG channels, starting from SSGA
        xor     a

_update_loop:
        call    ssg_ctx_set_current

        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        cp      #0
        jp      z, _end_ssg_channel_pipeline

        ;; Pipeline action: evaluate one macro step to update current state
        bit     BIT_EVAL_MACRO, PIPELINE(ix)
        jr      z, _ssg_pipeline_post_macro
        res     BIT_EVAL_MACRO, PIPELINE(ix)

        ;; the macro evaluation decides whether or not to load
        ;; registers later in the pipeline, and if we must continue
        ;; to evaluation the macro during the next pipeline run
        call    eval_macro_step
_ssg_pipeline_post_macro::


        ;; Pipeline action: evaluate one FX step for each enabled FX

        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _ssg_post_fx_trigger
        ld      hl, #state_ssg_action_funcs
        call    eval_trigger_step
_ssg_post_fx_trigger:
        bit     BIT_FX_VIBRATO, FX(ix)
        jr      z, _ssg_post_fx_vibrato
        call    eval_ssg_vibrato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_ssg_post_fx_vibrato:
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _ssg_post_fx_slide
        ld      hl, #NOTE
        call    eval_ssg_slide_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_ssg_post_fx_slide:
        bit     BIT_FX_VOL_SLIDE, FX(ix)
        jr      z, _ssg_post_fx_vol_slide
        call    eval_vol_slide_step
        set     #BIT_LOAD_VOL, PIPELINE(ix)
_ssg_post_fx_vol_slide:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _ssg_post_check_playing
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_ssg_post_check_playing:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      z, _post_load_ssg_note
        res     BIT_LOAD_NOTE, PIPELINE(ix)

        call    compute_ssg_fixed_point_note
        call    compute_ym2610_ssg_note

        ;; YM2610: load note
        ld      a, (state_ssg_channel)
        sla     a
        add     #REG_SSG_A_FINE_TUNE
        ld      b, a
        ld      c, NOTE_FINE_COARSE(ix)
        call    ym2610_write_port_a
        inc     b
        ld      c, NOTE_FINE_COARSE+1(ix)
        call    ym2610_write_port_a
_post_load_ssg_note:

        ;; Pipeline action: load registers modified by macros
        ;; (do not load if macro is finished)
        bit     BIT_LOAD_REGS, PIPELINE(ix)
        jr      z, _post_ssg_macro_load
        res     BIT_LOAD_REGS, PIPELINE(ix)
_prepare_ld_call:

        ;; de: return address
        ld      de, #_post_ssg_macro_load
        push    de

        ;; bc: load_func for this SSG channel
        ld      c, MACRO_LOAD(ix)
        ld      b, MACRO_LOAD+1(ix)
        push    bc

        ;; call args: hl: state_mirrored_ssg_props (8bit aligned add)
        push    ix
        pop     hl
        ld      a, l
        add     #PROPS_OFFSET
        ld      l, a

        ;; indirect call
        ret

_post_ssg_macro_load:

        ;; Pipeline action: load volume registers when the volume state is modified
        ;; Note: this is after macro load as currently, this step sets the VOL LOAD
        ;; bit if the macro updated the volume register
        bit     BIT_LOAD_VOL, PIPELINE(ix)
        jr      z, _post_load_ssg_vol
        res     BIT_LOAD_VOL, PIPELINE(ix)

        call    compute_ym2610_ssg_vol

        ;; load into ym2610
        ld      c, OUT_VOL(ix)
        ld      a, (state_ssg_channel)
        add     #REG_SSG_A_VOLUME
        ld      b, a
        call    ym2610_write_port_a
_post_load_ssg_vol:


        ;; Pipeline action: configure waveform and start note playback
        ld      c, #0xff
        bit     BIT_LOAD_WAVEFORM, PIPELINE(ix)
        jr      z, _post_load_waveform
        res     BIT_LOAD_WAVEFORM, PIPELINE(ix)
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        ;; c: waveform (shifted for channel)
        ;; b: waveform mask (shifted for channel)
        ld      c, WAVEFORM_OFFSET(ix)
        call    waveform_for_channel

        ;; start note
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _post_load_waveform
        ld      a, (state_mirrored_enabled)
        and     b
        or      c
        ld      (state_mirrored_enabled), a
        ld      b, #REG_SSG_ENABLE
        ld      c, a
        call    ym2610_write_port_a
        set     BIT_NOTE_STARTED, PIPELINE(ix)
_post_load_waveform:

_end_ssg_channel_pipeline:
        ;; next ssg context
        ld      a, (state_ssg_channel)
        inc     a
        cp      #3
        jr      nc, _ssg_end_macro
        call    ssg_ctx_set_current
        jp      _update_loop

_ssg_end_macro:
        ;; restore the real ssg channel context
        pop     af
        call    ssg_ctx_set_current

        pop     ix
        pop     iy
        pop     de
        ret


;;; Update the current fixed-point position
;;; ------
;;; current note (integer) + all the note effects (fixed point)
compute_ssg_fixed_point_note::
        ;; hl: from currently configured note (fixed point)
        ld      a, #0
        ld      l, a
        ld      h, NOTE(ix)

        ;; hl: detuned semitone
        ld      c, DETUNE(ix)
        ld      b, DETUNE+1(ix)
        add     hl, bc

        ;; h: current note + arpeggio shift
        ld      a, ARPEGGIO(ix)
        add     h
        ld      h, a

        ld      a, FX(ix)

        ;; bc: add vibrato offset if the vibrato FX is enabled
        bit     0, a
        jr      z, _ssg_post_add_vibrato
        ld      c, VIBRATO_POS16(ix)
        ld      b, VIBRATO_POS16+1(ix)
        add     hl, bc
_ssg_post_add_vibrato::
        ;; bc: add slide offset if the slide FX is enabled
        bit     1, a
        jr      z, _ssg_post_add_slide
        ld      c, SLIDE_POS16(ix)
        ld      b, SLIDE_POS16+1(ix)
        add     hl, bc
_ssg_post_add_slide::

        ;; update computed fixed-point note position
        ld      NOTE_POS16(ix), l
        ld      NOTE_POS16+1(ix), h
        ret

compute_ym2610_ssg_note::
        ;; b: current note (integer part)
        ld      b, NOTE_POS16+1(ix)

        ;; b: octave and semitone from note
        ld      hl, #note_to_octave_semitone
        ld      a, l
        add     b
        ld      l, a
        ld      b, (hl)

        ;; de: ym2610 base tune for note
        ld      hl, (state_ssg_tune)
        ld      a, b
        sla     a
        ld      l, a
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        push    de              ; +base tune

        ;; e: half-distance SSG tune to next semitone
        ld      hl, (state_ssg_semitone_distance)
        ld      a, l
        add     b
        ld      l, a
        ld      e, (hl)
        ;; c: SSG: intermediate frequency is negative
        ld      c, #1
        ;; b: intermediate note position (fractional part)
        ld      b, NOTE_POS16(ix)
        ;; de: current intermediate SSG tune
        call    slide_intermediate_freq
        push    hl
        pop     de

        ;; hl: ym2610 tune (coarse | fine tune)
        pop     hl              ; -base tune
        add     hl, de

        ;; save ym2610 fine and coarse tune
        ld      NOTE_FINE_COARSE(ix), l
        ld      NOTE_FINE_COARSE+1(ix), h
        ret


;;; Blend all volumes together to yield the volume for the ym2610 register
;;; ------
;;; [b modified]
compute_ym2610_ssg_vol::
        ;; a: current note volume for channel
        ld      a, REG_VOL(ix)
        and     #0xf

        ;; substract slide down FX volume if used (attenuation)
        bit     BIT_FX_VOL_SLIDE, FX(ix)
        jr      z, _post_ssg_sub_vol_slide
        sub     VOL_SLIDE_POS16+1(ix)
_post_ssg_sub_vol_slide:

        ;; substract configured volume (attenuation)
        sub     VOL(ix)

        ;; substract global volume attenuation
        ;; NOTE: YM2610's SSG output level ramp follows an exponential curve,
        ;; so we implement this output level attenuation via a basic substraction
        ld      b, a
        ld      a, (state_ssg_volume_attenuation)
        neg
        add     b

        ;; clamp result volume
        bit     7, a
        jr      z, _post_ssg_vol_clamp
        ld      a, #0
_post_ssg_vol_clamp:

        ld      OUT_VOL(ix), a
        ret


;;; Set the right waveform value for the current SSG channel
;;; ------
;;; IN:
;;;   c: waveform
;;; OUT
;;;   c: shifted waveform for the current channel
;;; [b, c modified]
waveform_for_channel:
        ld      b, #0xf6   ; 11110110
        ld      a, (state_ssg_channel)
        cp      #0
        jp      z, _post_waveform_shift
        rlc     b
        rlc     c
        dec     a
        jp      z, _post_waveform_shift
        rlc     b
        rlc     c
_post_waveform_shift:
        ret


;;;  Reset SSG playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
ssg_ctx_reset::
        ld      a, #0
        call    ssg_ctx_set_current
        ret




;;; SSG NSS opcodes
;;; ------

;;; SSG_CTX_1
;;; Set the current SSG track to be SSG1 for the next SSG opcode processing
;;; ------
ssg_ctx_1::
        ;; set new current SSG channel
        ld      a, #0
        call    ssg_ctx_set_current
        ld      a, #1
        ret


;;; SSG_CTX_2
;;; Set the current SSG track to be SSG3 for the next SSG opcode processing
;;; ------
ssg_ctx_2::
        ;; set new current SSG channel
        ld      a, #1
        call    ssg_ctx_set_current
        ld      a, #1
        ret


;;; SSG_CTX_3
;;; Set the current SSG track to be SSG3 for the next SSG opcode processing
;;; ------
ssg_ctx_3::
        ;; set new current SSG channel
        ld      a, #2
        call    ssg_ctx_set_current
        ld      a, #1
        ret


;;; SSG_MACRO
;;; Configure the SSG channel based on a macro's data
;;; ------
;;; [ hl ]: macro number
ssg_macro::
        push    de

        ;; init current state prior to loading new macro
        ;; to clean up any unused macro state
        ld      a, #0
        ld      ARPEGGIO(ix), a

        ;; a: macro
        ld      a, (hl)
        inc     hl

        push    hl

        ;; hl: macro address from instruments
        ld      hl, (state_stream_instruments)
        sla     a
        ;; hl + a (8bit add)
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a

        ;; hl: macro definition in (hl)
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      h, d
        ld      l, e

        ;; initialize the state of the new macro
        ld      a, (hl)
        ld      MACRO_LOAD(ix), a
        inc     hl
        ld      a, (hl)
        ld      MACRO_LOAD+1(ix), a
        inc     hl
        ld      MACRO_DATA(ix), l
        ld      MACRO_DATA+1(ix), h
        ld      MACRO_POS(ix), l
        ld      MACRO_POS+1(ix), h

        ;; reconfigure pipeline to start evaluating macro
        ld      a, PIPELINE(ix)
        or      #STATE_EVAL_MACRO
        ld      PIPELINE(ix), a

        ;; setting a new instrument/macro always trigger a note start,
        ;; register it for the next pipeline run
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        pop     hl
        pop     de

        ld      a, #1
        ret


;;; Update the vibrato for the current SSG channel
;;; ------
;;; ix: mirrored state of the current fm channel
eval_ssg_vibrato_step::
        push    hl
        push    de
        push    bc

        call    vibrato_eval_step

        pop     bc
        pop     de
        pop     hl

        ret


;;; Update the slide for the current channel
;;; Slide moves up or down by 1/8 of semitone increments * slide depth.
;;; ------
;;; IN:
;;;   hl: state for the current channel
;;; OUT:
;;;   bc:
eval_ssg_slide_step::
        push    de

        ;; update internal state for the next slide step
        call    eval_slide_step

        ;; effect still in progress?
        cp      a, #0
        jp      nz, _end_ssg_slide_step
        ;; otherwise set the end note as the new base note
        ld      a, NOTE(ix)
        add     d
        ld      NOTE(ix), a
_end_ssg_slide_step:

        pop     de

        ret


;;; Release the note on a SSG channel and update the pipeline state
;;; ------
ssg_stop_playback:
        push    bc

        ;; c: disable mask (shifted for channel)
        ld      c, #9           ; ..001001
        call    waveform_for_channel

        ;; stop channel
        ld      a, (state_mirrored_enabled)
        or      c
        ld      (state_mirrored_enabled), a
        ld      b, #REG_SSG_ENABLE
        ld      c, a
        call    ym2610_write_port_a

        ;; mute channel volume
        ld      a, (state_ssg_channel)
        add     #REG_SSG_A_VOLUME
        ld      b, a
        ld      c, #0
        call    ym2610_write_port_a

        pop     bc

        ;; disable playback in the pipeline, any note lod_note bit
        ;; will get cleaned during the next pipeline run
        res     BIT_PLAYING, PIPELINE(ix)

        ;; record that playback is stopped
        xor     a
        res     BIT_NOTE_STARTED, PIPELINE(ix)

        ret


;;; SSG_NOTE_OFF
;;; Release (stop) the note on the current SSG channel.
;;; ------
ssg_note_off::
        call    ssg_stop_playback

        ;; SSG context will now target the next channel
        ld      a, (state_ssg_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; SSG_VOL
;;; Set the volume of the current SSG channel
;;; ------
;;; [ hl ]: volume level
ssg_vol::
        ;; a: attenuation (15-volume)
        ld      a, (hl)
        inc     hl
        sub     a, #15
        neg

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _ssg_vol_immediate
        ld      TRIGGER_VOL(ix), a
        set     BIT_TRIGGER_LOAD_VOL, TRIGGER_ACTION(ix)
        jr      _ssg_vol_end

_ssg_vol_immediate:
        ;; else load vol immediately
        call    ssg_configure_vol

_ssg_vol_end:

        ld      a, #1
        ret


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
ssg_configure_note_on:
        push    bc
        push    af              ; +note
        ;; if portamento is ongoing, this is treated as an update
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _ssg_cfg_note_update
        ld      a, SLIDE_PORTAMENTO(ix)
        cp      #0
        jr      z, _ssg_cfg_note_update
        ;; update the portamento now
        pop     af              ; -note
        ld      SLIDE_PORTAMENTO(ix), a
        ld      b, NOTE(ix)
        call    slide_portamento_finish_init
        ;; if a note is currently playing, do nothing else, the
        ;; portamento will be updated at the next pipeline run...
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _ssg_cfg_note_end
        ;; ... else a new instrument was loaded, reload this note as well
        jr      _ssg_cfg_note_prepare_ym2610
_ssg_cfg_note_update:
        ;; update the current note and prepare the ym2610
        pop     af              ; -note
        ld      NOTE(ix), a
_ssg_cfg_note_prepare_ym2610:
        ;; init macro position
        ld      a, MACRO_DATA(ix)
        ld      MACRO_POS(ix), a
        ld      a, MACRO_DATA+1(ix)
        ld      MACRO_POS+1(ix), a

        ;; reload all registers at the next pipeline run
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        ld      a, PIPELINE(ix)
        or      #(STATE_PLAYING|STATE_EVAL_MACRO|STATE_LOAD_NOTE)
        ld      PIPELINE(ix), a

_ssg_cfg_note_end:
        pop     bc

        ret


;;; Configure state for new volume and trigger a load in the pipeline
;;; ------
ssg_configure_vol:
        ld      VOL(ix), a

        ;; reload configured vol at the next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)

        ret


;;; SSG_NOTE_ON
;;; Emit a specific note (frequency) on a SSG channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
ssg_note_on::
        ;; a: note (0xAB: A=octave B=semitone)
        ld      a, (hl)
        inc     hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _ssg_note_on_immediate
        ld      TRIGGER_NOTE(ix), a
        set     BIT_TRIGGER_LOAD_NOTE, TRIGGER_ACTION(ix)
        jr      _ssg_note_on_end

_ssg_note_on_immediate:
        ;; else load note immediately
        call    ssg_configure_note_on

_ssg_note_on_end:
        ;; ssg context will now target the next channel
        ld      a, (state_ssg_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; SSG_NOTE_ON_AND_WAIT
;;; Emit a specific note (frequency) on a SSG channel and
;;; immediately wait as many rows as the last wait
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
ssg_note_on_and_wait::
        ;; process a regular note opcode
        call    ssg_note_on

        ;; wait rows
        call    wait_last_rows
        ret


;;; SSG_ENV_PERIOD
;;; Set the period of the SSG envelope generator
;;; ------
;;; [ hl ]: fine envelope period
;;; [hl+1]: coarse envelope period
ssg_env_period::
        push    bc

        ld      b, #REG_SSG_ENV_FINE_TUNE
        ld      a, (hl)
        inc     hl
        ld      c, a
        call    ym2610_write_port_a

        inc     b
        ld      a, (hl)
        inc     hl
        ld      c, a
        call    ym2610_write_port_a

        pop     bc

        ld      a, #1
        ret


;;; SSG_VIBRATO
;;; Enable vibrato for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_vibrato::
        ;; TODO: move this part to common vibrato_init

        ;; hl == 0 means disable vibrato
        ld      a, (hl)
        cp      #0
        jr      nz, _setup_ssg_vibrato

        ;; disable vibrato FX
        res     BIT_FX_VIBRATO, FX(ix)

        ;; reload configured note at the next pipeline run
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        inc     hl
        jr      _post_ssg_setup

_setup_ssg_vibrato:
        call    vibrato_init

_post_ssg_setup:

        ld      a, #1
        ret


;;; SSG_SLIDE_UP
;;; Enable slide up effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; SSG_SLIDE_DOWN
;;; Enable slide down effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
ssg_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; SSG_PITCH_SLIDE_UP
;;; Enable slide up effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (8bits)
ssg_pitch_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; SSG_PITCH_SLIDE_DOWN
;;; Enable slide up effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (8bits)
ssg_pitch_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; SSG_PORTAMENTO
;;; Enable slide to the next note to be loaded into the pipeline
;;; ------
;;; [ hl ]: speed
ssg_portamento::
        ;; current note (start of portamento)
        ld      a, NOTE_POS16+1(ix)

        call    slide_portamento_init

        ld      a, #1
        ret


;;; SSG_VOL_SLIDE_DOWN
;;; Enable volume slide down effect for the current SSG channel
;;; ------
;;; [ hl ]: speed (4bits)
ssg_vol_slide_down::
        push    bc
        push    de

        ld      bc, #0x40
        ld      d, #15
        ld      a, #1
        call    vol_slide_init

        pop     de
        pop     bc

        ld      a, #1
        ret


;;; SSG_DELAY
;;; Enable delayed trigger for the next note and volume
;;; (note and volume and played after a number of ticks)
;;; ------
;;; [ hl ]: delay
ssg_delay::
        call    trigger_delay_init

        ld      a, #1
        ret


;;; SSG_PITCH
;;; Detune up to -+1 semitone for the current channel
;;; ------
;;; [ hl ]: detune
ssg_pitch::
        push    bc
        call    common_pitch
        ld      DETUNE(ix), c
        ld      DETUNE+1(ix), b
        pop     bc
        ld      a, #1
        ret


;;; SSG_CUT
;;; Record that the note being played must be stopped after some steps
;;; ------
;;; [ hl ]: delay
ssg_cut::
        call    trigger_cut_init

        ld      a, #1
        ret
