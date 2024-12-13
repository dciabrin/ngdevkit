;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2023 Damien Ciabrini
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

;;; NSS opcode for ADPCM channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .lclequ ADPCM_A_STATE_SIZE,(state_a_end-state_a)

        ;; getters for ADPCM-A state
        .lclequ VOL, (state_a_vol-state_a)
        .lclequ OUT_VOL, (state_a_out_vol-state_a)

        .equ    NSS_ADPCM_A_INSTRUMENT_PROPS,   4
        .equ    NSS_ADPCM_A_NEXT_REGISTER,      8


        ;; pipeline state for ADPCM-A channel
        .lclequ STATE_PLAYING,      0x01
        .lclequ STATE_EVAL_MACRO,   0x02
        .lclequ STATE_START,        0x04
        .lclequ STATE_LOAD_VOL,     0x08
        .lclequ STATE_LOAD_PAN,     0x10
        .lclequ BIT_PLAYING,        0
        .lclequ BIT_EVAL_MACRO,     1
        .lclequ BIT_START,          2
        .lclequ BIT_LOAD_VOL,       3
        .lclequ BIT_LOAD_PAN,       4



        .area  DATA

;;; ADPCM playback state tracker
;;; ------
        ;; This padding ensures the entire _state_ssg data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   42

_state_adpcm_start:

;;; ADPCM-A mirrored state
state_a:
;;; ADPCM-A1
state_a1:
state_a_pipeline:               .blkb   1       ; actions to run at every tick (load note, vol, other regs)
state_a_fx:                     .blkb   1       ; enabled FX for this channel
;;; FX state trackers
state_a_trigger:                .blkb   TRIGGER_SIZE
;;; ADPCM-A-specific state
;;; volume
state_a_vol:                    .blkb    1      ; configured note volume (attenuation)
state_a_out_vol:                .blkb    1      ; ym2610 volume after the FX pipeline
;;;
state_a_end:
;;; ADPCM-A2
state_a2:
.blkb   ADPCM_A_STATE_SIZE
;;; ADPCM-A3
state_a3:
.blkb   ADPCM_A_STATE_SIZE
;;; ADPCM-A4
state_a4:
.blkb   ADPCM_A_STATE_SIZE
;;; ADPCM-A5
state_a5:
.blkb   ADPCM_A_STATE_SIZE
;;; ADPCM-A6
state_a6:
.blkb   ADPCM_A_STATE_SIZE
state_a6_end:

;;; context: current adpcm channel for opcode actions
state_adpcm_a_channel::
        .db     0


;;; Global volume attenuation for all ADPCM-A channels
state_adpcm_a_volume_attenuation::   .blkb   1


_state_adpcm_end:

        .area  CODE

;;; context: channel action functions for FM
state_a_action_funcs::
        .dw     adpcm_a_configure_on
        .dw     adpcm_a_configure_vol
        .dw     adpcm_a_stop_playback


;;;  Reset ADPCM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_adpcm_state_tracker::
        ld      hl, #state_a
        ld      d, h
        ld      e, l
        inc     de
        ;; zero states
        ld      (hl), #0
        ld      bc, #(state_a6_end-1-state_a)
        ldir
        ;; init flags
        ld      a, #0
        ld      (state_adpcm_a_channel), a
        ;; set default
        ld      ix, #state_a1
        ld      d, #6
_a_init:
        ld      a, #0x1f
        ld      VOL(ix), a
        dec     d
        jr      nz, _a_init
        ;; global ADPCM volumes are initialized in the volume state tracker
        ret

;;;  Reset ADPCM-A playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
adpcm_a_ctx_reset::
        ld      a, #0
        ld      (state_adpcm_a_channel), a
        ret


;;; Set the current ADPCM-A track and YM2610 load function for this track
;;; ------
;;;   a : ADPCM-A channel
adpcm_a_ctx_set_current::
        ;; set ADPCM-A context
        ld      (state_adpcm_a_channel), a

        ;; set ADPCM-A struct pointer for context
        ld      ix, #state_a
        push    bc
        bit     0, a
        jr      z, _adpcm_a_ctx_post_bit0
        ld      bc, #ADPCM_A_STATE_SIZE
        add     ix, bc
_adpcm_a_ctx_post_bit0:
        bit     1, a
        jr      z, _adpcm_a_ctx_post_bit1
        ld      bc, #ADPCM_A_STATE_SIZE*2
        add     ix, bc
_adpcm_a_ctx_post_bit1:
        bit     2, a
        jr      z, _adpcm_a_ctx_post_bit2
        ld      bc, #ADPCM_A_STATE_SIZE*4
        add     ix, bc
_adpcm_a_ctx_post_bit2:
        pop     bc

        ;; return 1 to follow NSS processing semantics
        ld      a, #1
        ret


;;; run_adpcm_a_pipeline
;;; ------
;;; Run the entire ADPCM-A pipeline once. for each ADPCM-A channels:
;;;  - update the state of all enabled FX
;;;  - load specific parts of the state (pan, vol...) into ADPCM-A registers
;;; Meant to run once per tick
run_adpcm_a_pipeline::
        push    de
        push    iy
        push    ix

        ;; we loop though every channel during the execution,
        ;; so save the current channel context
        ld      a, (state_adpcm_a_channel)
        push    af

        ;; update state of all ADPCM-A channels, starting from A1
        xor     a
_a_update_loop:
        call    adpcm_a_ctx_set_current

        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        cp      #0
        jp      z, _end_a_channel_pipeline

        ;; Pipeline action: evaluate one FX step for each enabled FX

        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _a_post_fx_trigger
        ld      hl, #state_a_action_funcs
        call    eval_trigger_step
_a_post_fx_trigger:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _a_post_check_playing
        res     BIT_START, PIPELINE(ix)
_a_post_check_playing:

        ;; Pipeline action: compute volume registers when the volume state is modified
        bit     BIT_LOAD_VOL, PIPELINE(ix)
        jr      z, _post_load_a_vol
        call    compute_ym2610_a_vol
_post_load_a_vol:

        ;; Pipeline action: load pan+volume register when it is modified
        ld      a, PIPELINE(ix)
        or      a, #(STATE_LOAD_VOL|STATE_LOAD_PAN)
        jr      z, _post_load_a_pan_vol
        res     BIT_LOAD_VOL, PIPELINE(ix)
        res     BIT_LOAD_PAN, PIPELINE(ix)

        ;; c: volume + default pan (L/R)
        ld      a, OUT_VOL(ix)
        or      #0xc0
        ld      c, a

        ;; set pan+volume for channel in the YM2610
        ;; b: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        add     a, #REG_ADPCM_A1_PAN_VOLUME
        ld      b, a
        call    ym2610_write_port_b
_post_load_a_pan_vol:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_START, PIPELINE(ix)
        jr      z, _post_load_a_note
        res     BIT_START, PIPELINE(ix)

        ;; d: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        ld      d, a

        ;; a: bitwise channel
        ld      a, #0
        inc     d
        scf
_a_on_bit:
        rla
        dec     d
        jp      nz, _a_on_bit

        ;; start channel
        ld      b, #REG_ADPCM_A_START_STOP
        ld      c, a
        call    ym2610_write_port_b

_post_load_a_note:

_end_a_channel_pipeline:
        ;; next context
        ld      a, (state_adpcm_a_channel)
        inc     a
        cp      #6
        jr      nc, _a_end_pipeline
        jp      _a_update_loop

_a_end_pipeline:
        ;; restore the real channel context
        pop     af
        call    adpcm_a_ctx_set_current

        pop     ix
        pop     iy
        pop     de
        ret


;;; ADPCM NSS opcodes
;;; ------

;;; ADPCM_A_CTX_1
;;; Set the current ADPCM-A context to channel 1 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_1::
        ;; set new current ADPCM-A channel
        ld      a, #0
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_CTX_2
;;; Set the current ADPCM-A context to channel 2 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_2::
        ;; set new current ADPCM-A channel
        ld      a, #1
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_CTX_3
;;; Set the current ADPCM-A context to channel 3 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_3::
        ;; set new current ADPCM-A channel
        ld      a, #2
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_CTX_4
;;; Set the current ADPCM-A context to channel 4 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_4::
        ;; set new current ADPCM-A channel
        ld      a, #3
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_CTX_5
;;; Set the current ADPCM-A context to channel 5 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_5::
        ;; set new current ADPCM-A channel
        ld      a, #4
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_CTX_6
;;; Set the current ADPCM-A context to channel 6 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_6::
        ;; set new current ADPCM-A channel
        ld      a, #5
        jp      adpcm_a_ctx_set_current


;;; ADPCM_A_INSTRUMENT
;;; Configure an ADPCM-A channel based on an instrument's data
;;; ------
;;; [ hl ]: instrument number
adpcm_a_instrument::
        push    bc

        ;; b: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        ld      b, a
        ;; a: instrument
        ld      a, (hl)
        inc     hl

        push    hl
        push    de

        ;; hl: instrument address in ROM
        ;; (ADPCM-A channel still saved in b)
        sla     a
        ld      c, a
        ld      a, b
        ld      b, #0
        ld      hl, (state_stream_instruments)
        add     hl, bc
        ld      b, a
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        push    de
        pop     hl

        ;; d: all ADPCM-A properties
        ld      d, #NSS_ADPCM_A_INSTRUMENT_PROPS

        ;; b: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        ld      b, a

        ;; a: start of ADPCM-A property registers
        ld      a, #REG_ADPCM_A1_ADDR_START_LSB
        add     b

_adpcm_a_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_b
        add     a, #NSS_ADPCM_A_NEXT_REGISTER
        inc     hl
        dec     d
        jp      nz, _adpcm_a_loop

        ;; d: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        ld      d, a

        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
adpcm_a_configure_on:
        ;; load a new note means "restart the current sample"

        ld      a, PIPELINE(ix)
        or      #(STATE_PLAYING|STATE_START)
        ld      PIPELINE(ix), a

        ret


;;; Configure state for new volume and trigger a load in the pipeline
;;; ------
adpcm_a_configure_vol:
        ld      VOL(ix), a

        ;; reload configured vol at the next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)

        ret


;;; ADPCM_A_ON
;;; Start sound playback on the current ADPCM-A channel
;;; ------
;;; [ hl ]: ADPCM-A channel [0..5]
adpcm_a_on::
        ;; delay the start via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _a_on_immediate
        ;; ld      TRIGGER_NOTE(ix), a
        set     BIT_TRIGGER_LOAD_NOTE, TRIGGER_ACTION(ix)
        jr      _a_on_end

_a_on_immediate:
        ;; else load note immediately
        call    adpcm_a_configure_on

_a_on_end:

        ;; ADPCM-A context will now target the next channel
        ld      a, (state_adpcm_a_channel)
        inc     a
        ld      (state_adpcm_a_channel), a

        ld      a, #1
        ret


;;; Release the note on a ADPCM-A channel and update the pipeline state
;;; ------
adpcm_a_stop_playback:
        push    bc
        push    de

        ;; d: ADPCM-A channel (1..6)
        ld      a, (state_adpcm_a_channel)
        inc     a
        ld      d, a

        ;; a: bit channel + stop bit
        ld      a, #0
        scf
_off_bit:
        rla
        dec     d
        jp      nz, _off_bit
        or      #0x80

        ;; start channel
        ld      b, #0
        ld      c, a
        call    ym2610_write_port_b

        pop     de
        pop     bc

        ret


;;; ADPCM_A_OFF
;;; Stop the playback on a ADPCM-A channel
;;; ------
adpcm_a_off::
        call    adpcm_a_stop_playback

        ;; ADPCM-A context will now target the next channel
        ld      a, (state_adpcm_a_channel)
        inc     a
        ld      (state_adpcm_a_channel), a

        ld      a, #1
        ret


;;; adpcm_a_scale_output
;;; adjust a channel volume to match configured ADPCM-A output level
;;; the YM2610's ADPCM-A output level ramp follows an exponential
;;; curve, so we implement this output level attenuation via a basic
;;; substraction, clamped to 0.
;;; ------
;;; a: input level [0x00..0x1f]
;;; modified: bc
adpcm_a_scale_output::
        ;; b: pan info
        ld      c, a
        and     #0xc0
        ld      b, a

        ;; c: volume info
        ld      a, c
        and     #0x1f
        ld      c, a

        ;; attenuation to match the configured ADPCM-A output level
        ld      a, (state_adpcm_a_volume_attenuation)
        neg
        add     c
        bit     7, a
        jr      nz, _adpcm_a_clamp_level
        ;; restore pan info
        add     b
        ret
_adpcm_a_clamp_level:
        ;; NOTE: ADPCM-A oddity: it seems that channels with volume set to 0
        ;; still outputs something? For now, reset the pan to force mute
        ld      a, #0
        ret


;;; Compute the YM2610 output volume from the current channel
;;; ------
;;; modified: c
compute_ym2610_a_vol::
        ld      c, VOL(ix)

        ;; attenuation to match the configured ADPCM-A output level
        ld      a, (state_adpcm_a_volume_attenuation)
        neg
        add     c
        bit     7, a
        jr      z, _a_post_global_vol
        xor     a
_a_post_global_vol:
        ld      OUT_VOL(ix), a

        ret


;;; ADPCM_A_VOL
;;; Register a pending volume change for the current ADPCM-A channel
;;; The next note to be played or instrument change will pick
;;; up this volume configuration change
;;; ------
;;; [ hl ]: volume [0-0x1f]
adpcm_a_vol::
        ;; a: volume
        ld      a, (hl)
        inc     hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _a_vol_immediate
        ld      TRIGGER_VOL(ix), a
        set     BIT_TRIGGER_LOAD_VOL, TRIGGER_ACTION(ix)
        jr      _a_vol_end

_a_vol_immediate:
        ;; else load vol immediately
        call    adpcm_a_configure_vol

_a_vol_end:
        ld      a, #1
        ret


;;; ADPCM_A_DELAY
;;; Enable delayed trigger for the next note and volume
;;; (note and volume and played after a number of ticks)
;;; ------
;;; [ hl ]: delay
adpcm_a_delay::
        call    trigger_delay_init

        ld      a, #1
        ret


;;; ADPCM_A_CUT
;;; Record that the note being played must be stopped after some steps
;;; ------
;;; [ hl ]: delay
adpcm_a_cut::
        call    trigger_cut_init

        ld      a, #1
        ret


;;; ADPCM_A_RETRIGGER
;;; Enable another trigger of the current note after a number of steps
;;; ------
;;; [ hl ]: delay
adpcm_a_retrigger::
        call    trigger_retrigger_init

        ld      a, #1
        ret
