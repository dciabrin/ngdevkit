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

;;; NSS opcode for ADPCM-B channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .lclequ ADPCM_B_STATE_SIZE,(state_b_end-state_b)

        ;; getters for ADPCM-B state
        .lclequ NOTE, (state_b_note_semitone-state_b)
        .lclequ NOTE_SEMITONE, (state_b_note_semitone-state_b)
        .lclequ NOTE_POS16,(state_b_note_pos16-state_b)
        .lclequ DELTA_N, (state_b_note_delta_n-state_b)
        .lclequ VOL, (state_b_vol-state_b)
        .lclequ OUT_VOL, (state_b_out_vol-state_b)
        .lclequ PAN, (state_b_pan-state_b)
        .lclequ INSTR, (state_b_instr-state_b)
        .lclequ FINE_TUNE, (state_b_instr_fine_tune-state_b)
        .lclequ START_CMD, (state_b_instr_start_cmd-state_b)

        .equ    NSS_ADPCM_B_INSTRUMENT_PROPS,   4
        .equ    NSS_ADPCM_B_NEXT_REGISTER,      8

        ;; pipeline state for ADPCM-B channel
        .lclequ STATE_PLAYING,      0x01
        .lclequ STATE_EVAL_MACRO,   0x02
        .lclequ STATE_LOAD_NOTE,    0x04
        .lclequ STATE_LOAD_VOL,     0x08
        .lclequ STATE_LOAD_PAN,     0x10
        .lclequ STATE_NOTE_STARTED, 0x80
        .lclequ BIT_PLAYING,        0
        .lclequ BIT_EVAL_MACRO,     1
        .lclequ BIT_LOAD_NOTE,      2
        .lclequ BIT_LOAD_VOL,       3
        .lclequ BIT_LOAD_PAN,       4
        .lclequ BIT_NOTE_STARTED,   7


        .area  DATA

        ;; FIXME: temporary padding to ensures the next data sticks into
        ;; a single 256 byte boundary to make 16bit arithmetic faster
        .blkb   16

;;; Semitone Delta-N table in use (MVS or AES)
state_b_delta_n_base::
        .blkw   1

;;; Semitone Delta-N half-distance table in use (MVS or AES)
state_b_delta_n_half_distance::
        .blkw   1

;;; ADPCM playback state tracker
;;; ------
_state_adpcm_b_start:

;;; ADPCM-B mirrored state
state_b:
state_b_pipeline:               .blkb   1       ; actions to run at every tick (load note, vol, other regs)
state_b_fx:                     .blkb   1       ; enabled FX for this channel
;;; FX state trackers
state_b_trigger:                .blkb   TRIGGER_SIZE
state_b_fx_vol_slide:           .blkb   VOL_SLIDE_SIZE
state_b_fx_slide:               .blkb   SLIDE_SIZE
state_b_fx_vibrato:             .blkb   VIBRATO_SIZE
;;; ADPCM-B-specific state
;;; Note
state_b_note:
state_b_note_semitone:          .blkb   1       ; NSS note (octave+semitone) to be played
state_b_note_pos16:             .blkb   2       ; fixed-point note after the FX pipeline
state_b_note_delta_n:           .blkb   2       ; ym2610 delta-N after the FX pipeline
;;; instrument
state_b_instr:                  .blkb   1       ; instrument in use
state_b_instr_fine_tune:        .blkb   2       ; instrument fixed-point fine tuning for C-4 frequency
state_b_instr_start_cmd:        .blkb   1       ; instrument play command (with loop)
;;; volume
state_b_vol:                    .blkb   1       ; configured note volume (attenuation)
state_b_out_vol:                .blkb   1       ; ym2610 volume after the FX pipeline
;;; pan
state_b_pan:                    .blkb    1      ; configured pan (b7: left, b6: right)
;;;
state_b_end:


;;; Global volume attenuation for ADPCM-B channel
state_adpcm_b_volume_attenuation::   .blkb   1


_state_adpcm_b_end:

        .area  CODE

;;; context: channel action functions for FM
state_b_action_funcs::
        .dw     adpcm_b_configure_note_on
        .dw     adpcm_b_configure_vol
        .dw     adpcm_b_note_off


;;;  Reset ADPCM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_adpcm_b_state_tracker::
        ld      hl, #state_b
        ld      d, h
        ld      e, l
        inc     de
        ;; zero states
        ld      (hl), #0
        ld      bc, #(state_b_end-1-state_b)
        ldir
        ;; init flags
        ld      ix, #state_b
        ld      a, #0x80        ; start flag
        ld      START_CMD(ix), a
        ld      a, #0xff        ; default volume
        ld      VOL(ix), a
        ld      a, #0xff        ; default non-existing instrument
        ld      INSTR(ix), a
        ;; set up current F-num and half distance tables
        ld      bc, #adpcm_b_delta_n_base_aes
        ld      (state_b_delta_n_base), bc
        ld      bc, #adpcm_b_delta_n_half_distance_aes
        ld      (state_b_delta_n_half_distance), bc

        ;; global ADPCM volumes are initialized in the volume state tracker
        ret


;;; run_adpcm_b_pipeline
;;; ------
;;; Run the entire ADPCM-B pipeline once:
;;;  - update the state of all enabled FX
;;;  - load specific parts of the state (note, vol...) into ADPCM-B registers
;;; Meant to run once per tick
run_adpcm_b_pipeline::
        push    de
        push    iy
        push    ix

        call    adpcm_b_ctx

        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        cp      #0
        jp      z, _end_b_channel_pipeline

        ;; Pipeline action: evaluate one FX step for each enabled FX

        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _b_post_fx_trigger
        ld      hl, #state_b_action_funcs
        call    eval_trigger_step
_b_post_fx_trigger:
        bit     BIT_FX_VIBRATO, FX(ix)
        jr      z, _b_post_fx_vibrato
        call    eval_b_vibrato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_b_post_fx_vibrato:
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _b_post_fx_slide
        ld      hl, #NOTE_SEMITONE
        call    eval_b_slide_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_b_post_fx_slide:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _b_post_check_playing
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_b_post_check_playing:

        ;; Pipeline action: compute volume registers when the volume state is modified
        bit     BIT_LOAD_VOL, PIPELINE(ix)
        jr      z, _post_load_b_vol
        call    compute_ym2610_adpcm_b_vol

        ;; set volume in the YM2610
        ld      b, #REG_ADPCM_B_VOLUME
        ld      c, OUT_VOL(ix)
        call    ym2610_write_port_a
        res     BIT_LOAD_VOL, PIPELINE(ix)
_post_load_b_vol:

        ;; Pipeline action: load pan if requested
        bit     BIT_LOAD_PAN, PIPELINE(ix)
        jr      z, _post_load_b_pan
        ld      b, #REG_ADPCM_B_PAN
        ld      c, PAN(ix)
        call    ym2610_write_port_a
        res     BIT_LOAD_PAN, PIPELINE(ix)
_post_load_b_pan:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      z, _post_load_b_note
        res     BIT_LOAD_NOTE, PIPELINE(ix)

        call    compute_adpcm_b_fixed_point_note
        call    compute_ym2610_adpcm_b_note

        ;; configure delta_n into the YM2610
        ld      b, #REG_ADPCM_B_DELTA_N_LSB
        ld      c, DELTA_N(ix)
        call    ym2610_write_port_a
        ld      b, #REG_ADPCM_B_DELTA_N_MSB
        ld      c, DELTA_N+1(ix)
        call    ym2610_write_port_a

        ;; start the ADPCM-B playback if not already done
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _post_start_b
        ld      b, #REG_ADPCM_B_START_STOP
        ;; start command (with loop when configured)
        ld      a, START_CMD(ix)
        ld      c, a
        call    ym2610_write_port_a
        set     BIT_NOTE_STARTED, PIPELINE(ix)
_post_start_b:

_post_load_b_note:

_end_b_channel_pipeline:

        pop     ix
        pop     iy
        pop     de
        ret


;;; ADPCM NSS opcodes
;;; ------

;;; adpcm_b_scale_output
;;; adjust ADPCM-B volume to match configured ADPCM-B output level
;;; output volume = [0..1] * input volume, where the scale factor
;;; is the currently configured ADPCM-B output level [0x00..0xff]
;;; ------
;;; a: input level [0x00..0x1f]
;;; modified: bc
adpcm_b_scale_output::
        push    hl

        ;; bc: note volume fraction 000000fff fffff00
        ld      l, a
        ld      h, #0
        add     hl, hl
        add     hl, hl
        ld      c, l
        ld      b, h

        ;; init result
        ld      hl, #0

        ;; e: attenuation factor -> volume factor
        ld      a, (state_adpcm_b_volume_attenuation)
        neg
        add     #64
        ld      e, a

_b_level_bit0:
        bit     0, e
        jr      z, _b_level_bit1
        ;; add this bit's value to the result
        add     hl, bc
_b_level_bit1:
        ;; bc: bc * 2
        sla     c
        rl      b
        bit     1, e
        jr      z, _b_level_bit2
        add     hl, bc
_b_level_bit2:
        sla     c
        rl      b
        bit     2, e
        jr      z, _b_level_bit3
        add     hl, bc
_b_level_bit3:
        sla     c
        rl      b
        bit     3, e
        jr      z, _b_level_bit4
        add     hl, bc
_b_level_bit4:
        sla     c
        rl      b
        bit     4, e
        jr      z, _b_level_bit5
        add     hl, bc
_b_level_bit5:
        sla     c
        rl      b
        bit     5, e
        jr      z, _b_level_bit6
        add     hl, bc
_b_level_bit6:
        sla     c
        rl      b
        bit     6, e
        jr      z, _b_level_post
        add     hl, bc
_b_level_post:
        ;; keep the 8 MSB from hl, this is the scaled volume
        ld      a, h
        pop     hl
        ret


;;; ADPCM_B_INSTRUMENT
;;; Configure the ADPCM-B channel based on an instrument's data
;;; ------
;;; [ hl ]: instrument number
adpcm_b_instrument::
        ;; a: instrument
        ld      a, (hl)
        inc     hl

        ;; bail out if the current and new instruments are the same
        cp      INSTR(ix)
        jr      z, _adpcm_b_instr_end

        ld      INSTR(ix), a
        push    bc
        push    hl
        push    de

        ;; hl: instrument address in ROM
        sla     a
        ld      c, a
        ld      b, #0
        ld      hl, (state_stream_instruments)
        add     hl, bc
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        push    de
        pop     hl

        ;; d: all ADPCM-B properties
        ld      d, #4

        ;; a: start of ADPCM-B property registers
        ld      a, #REG_ADPCM_B_ADDR_START_LSB
        add     b

_adpcm_b_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_a
        add     a, #1
        inc     hl
        dec     d
        jp      nz, _adpcm_b_loop

        ;; play command, with/without loop bit
        ld      a, #0x80
        bit     0, (hl)
        jr      z, _adpcm_b_post_loop_chk
        set     4, a
_adpcm_b_post_loop_chk:
        ld      START_CMD(ix), a

        ;; instrument fine-tune for matching C-4 frequency
        inc     hl
        ld      a, (hl)
        ld      FINE_TUNE(ix), a
        inc     hl
        ld      a, (hl)
        ld      FINE_TUNE+1(ix), a

        ;; set a default pan
        ld      b, #REG_ADPCM_B_PAN
        ld      c, #0xc0        ; default pan (L+R)
        call    ym2610_write_port_a

        ;; setting a new instrument always trigger a note start,
        ;; register it for the next pipeline run
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        pop     de
        pop     hl
        pop     bc
_adpcm_b_instr_end:
        ld      a, #1
        ret


;;; Semitone frequency table
;;; ------
;;; A note in nullsound is represented as a tuple <octave, semitone>,
;;; which is translated into YM2610's register representation
;;; `Delta-N`. nullsounds decomposes Delta-N as `2^octave * base`,
;;; where base is a factor of the semitone's frequency, and the
;;; result is multiplied by a power of 2 (handy for octaves)
adpcm_b_delta_n_base_mvs:
        .db     0x0c, 0xb7	; 3255
        .db     0x0d, 0x78	; 3448
        .db     0x0e, 0x45	; 3653
        .db     0x0f, 0x1f	; 3871
        .db     0x10, 0x05	; 4101
        .db     0x10, 0xf9	; 4345
        .db     0x11, 0xfb	; 4603
        .db     0x13, 0x0d	; 4877
        .db     0x14, 0x2f	; 5167
        .db     0x15, 0x62	; 5474
        .db     0x16, 0xa8	; 5800
        .db     0x18, 0x00	; 6144

adpcm_b_delta_n_base_aes:
        .db     0x0c, 0xc4      ; 3268
        .db     0x0d, 0x86      ; 3462
        .db     0x0e, 0x55      ; 3669
        .db     0x0f, 0x2e      ; 3886
        .db     0x10, 0x16      ; 4118
        .db     0x11, 0x0b      ; 4363
        .db     0x12, 0x0e      ; 4622
        .db     0x13, 0x21      ; 4897
        .db     0x14, 0x45      ; 5189
        .db     0x15, 0x79      ; 5497
        .db     0x16, 0xc0      ; 5824
        .db     0x18, 0x1b      ; 6171


;;; Delta-N half-distance table
;;; ------
;;; The half-distance between a semitone's base delta-n and the next semitone's base delta-n.
;;; This is used to compute fractional delta-n values from fixed-point note.
adpcm_b_delta_n_half_distance_mvs::
        ;;         C,   C#,    D,   D#,    E,    F,   F#,    G,   G#,    A,   A#,    B
        .db     0x60, 0x66, 0x6d, 0x73, 0x7a, 0x81, 0x89, 0x91, 0x99, 0xa3, 0xac, 0xb7

adpcm_b_delta_n_half_distance_aes::
        ;;         C,   C#,    D,   D#,    E,    F,   F#,    G,   G#,    A,   A#,    B
        .db     0x61, 0x67, 0x6c, 0x74, 0x7a, 0x81, 0x89, 0x92, 0x9a, 0xa3, 0xad, 0xb7


;;; Update the vibrato for the ADPCM-B channel
;;; ------
;;; ix: mirrored state of the ADPCM-B channel
eval_b_vibrato_step::
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
eval_b_slide_step::
        push    hl
        push    de
        push    bc

        ;; update internal state for the next slide step
        call    eval_slide_step

        ;; effect still in progress?
        cp      a, #0
        jp      nz, _end_b_slide_load_fnum2
        ;; otherwise set the end note as the new base note
        ld      a, NOTE(ix)
        add     d
        ld      NOTE(ix), a
_end_b_slide_load_fnum2:

        pop     bc
        pop     de
        pop     hl

        ret


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
adpcm_b_configure_note_on:
        push    bc
        push    af              ; +note
        ;; if portamento is ongoing, this is treated as an update
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _b_cfg_note_update
        ld      a, SLIDE_PORTAMENTO(ix)
        cp      #0
        jr      z, _b_cfg_note_update
        ;; update the portamento now
        pop     af              ; -note
        ld      SLIDE_PORTAMENTO(ix), a
        ld      b, NOTE_SEMITONE(ix)
        call    slide_portamento_finish_init
        ;; if a note is currently playing, do nothing else, the
        ;; portamento will be updated at the next pipeline run...
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _b_cfg_note_end
        ;; ... else a new instrument was loaded, reload this note as well
        jr      _b_cfg_note_prepare_ym2610
_b_cfg_note_update:
        ;; update the current note and prepare the ym2610
        pop     af              ; -note
        ld      NOTE_SEMITONE(ix), a
_b_cfg_note_prepare_ym2610:
        ;; stop playback on the channel, and let the pipeline restart it
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #1           ; reset flag (clears start and repeat in YM2610)
        call    ym2610_write_port_a
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        ld      a, PIPELINE(ix)
        or      #(STATE_PLAYING|STATE_LOAD_NOTE)
        ld      PIPELINE(ix), a
_b_cfg_note_end:
        pop     bc
        ret


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
adpcm_b_configure_vol:
        ld      VOL(ix), a

        ;; reload configured vol at the next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)

        ret


;;; ADPCM_B_NOTE_ON
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: note
adpcm_b_note_on::
        ;; a: note
        ld      a, (hl)
        inc     hl
        push    hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _b_note_on_immediate
        ld      TRIGGER_NOTE(ix), a
        set     BIT_TRIGGER_LOAD_NOTE, TRIGGER_ACTION(ix)
        jr      _b_note_on_end

_b_note_on_immediate:
        ;; else load note immediately
        call    adpcm_b_configure_note_on

_b_note_on_end:
        pop     hl
        ld      a, #1
        ret


;;; Compute the YM2610's volume registers value from the ADPCM-B channel
;;; ------
;;; modified: bc
compute_ym2610_adpcm_b_vol::
        ;; a: note vol
        ld      a, VOL(ix)

        ;; scale volume based on global attenuation
        call    adpcm_b_scale_output

        ld      OUT_VOL(ix), a

        ret


;;; Compute fixed-point note position after FX-pipeline
;;; ------
;;; ix: state for the current channel
compute_adpcm_b_fixed_point_note::
        ;; hl: note from currently configured note (fixed point)
        ld      a, #0
        ld      l, a
        ld      h, NOTE_SEMITONE(ix)

        ;; bc: instrument fine tune
        ld      c, FINE_TUNE(ix)
        ld      b, FINE_TUNE+1(ix)
        add     hl, bc

        ;; bc: slide offset if the slide FX is enabled
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _b_post_add_slide
        ld      c, SLIDE_POS16(ix)
        ld      b, SLIDE_POS16+1(ix)
        add     hl, bc
_b_post_add_slide::

        ;; bc vibrato offset if the vibrato FX is enabled
        bit     BIT_FX_VIBRATO, FX(ix)
        jr      z, _b_post_add_vibrato
        ld      c, VIBRATO_POS16(ix)
        ld      b, VIBRATO_POS16+1(ix)
        add     hl, bc
_b_post_add_vibrato::

        ;; update computed fixed-point note position
        ld      NOTE_POS16(ix), l
        ld      NOTE_POS16+1(ix), h
        ret


;;; Compute the YM2610's note registers value from state's fixed-point note
;;; ------
;;; modified: bc, de, hl
compute_ym2610_adpcm_b_note::
        ;; d: current note
        ld      d, NOTE_POS16+1(ix)

        ;; d: octave and semitone from note
        ld      hl, #note_to_octave_semitone
        ld      a, l
        add     d
        ld      l, a
        ld      d, (hl)
        push    de              ; +octave/semitone

        ;; a: semitone
        ld      a, d
        and     #0xf

        ;; lh: semitone -> delta_n address
        ld      hl, (state_b_delta_n_base)
        sla     a
        ld      b, #0
        ld      c, a
        add     hl, bc

        ;; hl: base delta_n for semitone (integer part of note)
        ld      a, (hl)
        inc     hl
        ld      l, (hl)
        ld      h, a
        push    hl              ; +base delta-n

        ;; e: half-distance (base delta-n) to next semitone (8bit add)
        ld      a, d
        and     #0xf
        ld      hl, (state_b_delta_n_half_distance)
        add     l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a
        ld      e, (hl)
        ;; c: ADPCM-B: intermediate frequency is positive
        ld      c, #0
        ;; b: intermediate note position (fractional part)
        ld      b, NOTE_POS16(ix)
        ;; de: current intermediate base delta_n
        call    slide_intermediate_freq
        push    hl
        pop     de

        ;; hl: base delta_n for fixed-point note
        pop     hl              ; -base delta-n
        add     hl, de

        ;; d: octave
        pop     de              ; -octave/semitone
        srl     d
        srl     d
        srl     d
        srl     d

        ;; hl: delta_n (base << octave) for fixed-point note
        ld      a, d
        cp      #0
        jp      z, _no_delta_shift
_delta_shift:
        add     hl, hl
        dec     d
        jp      nz, _delta_shift
_no_delta_shift:

        ld      DELTA_N(ix), l
        ld      DELTA_N+1(ix), h

        ret


;;; ADPCM_B_NOTE_OFF
;;; Stop sample playback on the ADPCM-B channel
;;; ------
adpcm_b_note_off::
        push    bc

        ;; stop the ADPCM-B channel
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #1           ; reset flag (clears start and repeat in YM2610)
        call    ym2610_write_port_a

        ;; record that playback is stopped
        xor     a
        res     BIT_NOTE_STARTED, PIPELINE(ix)

        pop     bc
        ld      a, #1
        ret


;;; ADPCM_B_VOL
;;; Set playback volume of the ADPCM-B channel
;;; ------
adpcm_b_vol::
        ;; a: volume
        ld      a, (hl)
        inc     hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _b_vol_immediate
        ld      TRIGGER_VOL(ix), a
        set     BIT_TRIGGER_LOAD_VOL, TRIGGER_ACTION(ix)
        jr      _b_vol_end

_b_vol_immediate:
        ;; else load vol immediately
        call    adpcm_b_configure_vol

_b_vol_end:
        ld      a, #1
        ret


;;; ADPCM_B_CTX
;;; ------
;;; Set the current ctx for ADPCM-B
adpcm_b_ctx:
        ;; set ADPCM-B struct pointer for context
        ld      ix, #state_b

        ;; return 1 to follow NSS processing semantics
        ld      a, #1
        ret


;;; B_NOTE_SLIDE_UP
;;; Enable slide up effect for the ADPCM-B channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
b_note_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE_SEMITONE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; B_NOTE_SLIDE_DOWN
;;; Enable slide down effect for the ADPCM-B channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
b_note_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE_SEMITONE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; B_PITCH_SLIDE_UP
;;; Enable slide up effect for the ADPCM-B channel
;;; ------
;;; [ hl ]: speed (8bits)
b_pitch_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE_SEMITONE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; B_PITCH_SLIDE_DOWN
;;; Enable slide down effect for the ADPCM-B channel
;;; ------
;;; [ hl ]: speed (8bits)
b_pitch_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE_SEMITONE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; ADPCM_B_PORTAMENTO
;;; Enable slide to the next note to be loaded into the pipeline
;;; ------
;;; [ hl ]: speed
adpcm_b_portamento::
        ;; current note (start of portamento)
        ld      a, NOTE_POS16+1(ix)

        call    slide_portamento_init

        ld      a, #1
        ret


;;; ADPCM_B_DELAY
;;; Enable delayed trigger for the next note and volume
;;; (note and volume and played after a number of ticks)
;;; ------
;;; [ hl ]: delay
adpcm_b_delay::
        call    trigger_delay_init

        ld      a, #1
        ret


;;; ADPCM_B_CUT
;;; Record that the note being played must be stopped after some steps
;;; ------
;;; [ hl ]: delay
adpcm_b_cut::
        call    trigger_cut_init

        ld      a, #1
        ret


;;; ADPCM_B_PAN
;;; Set the pan (l/r) for the channel
;;; ------
;;; [ hl ]: pan (b7: left, b6: right)
adpcm_b_pan::
        ld      a, (hl)
        inc     hl
        ld      PAN(ix), a
        set     BIT_LOAD_PAN, PIPELINE(ix)

        ld      a, #1
        ret


;;; ADPCM_B_VIBRATO
;;; Enable vibrato for the channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
adpcm_b_vibrato::
        ;; TODO: move this part to common vibrato_init

        ;; hl == 0 means disable vibrato
        ld      a, (hl)
        cp      #0
        jr      nz, _setup_b_vibrato

        ;; disable vibrato fx
        res     BIT_FX_VIBRATO, FX(ix)

        ;; reload configured note at the next pipeline run
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        inc     hl
        jr      _post_b_vibrato_setup

_setup_b_vibrato:
        call    vibrato_init

_post_b_vibrato_setup:

        ld      a, #1
        ret
