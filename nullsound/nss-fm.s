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

;;; NSS opcode for FM channels
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .lclequ FM_STATE_SIZE,(state_fm_end-state_fm)

        ;; FM constants
        .lclequ NSS_FM_INSTRUMENT_PROPS,        28
        .lclequ NSS_FM_NEXT_REGISTER,           4
        .lclequ NSS_FM_NEXT_REGISTER_GAP,       16
        .lclequ NSS_FM_END_OF_REGISTERS,        0xb3
        .lclequ INSTR_TL_OFFSET,                30
        .lclequ INSTR_FB_ALGO_OFFSET,           28
        .lclequ INSTR_ALGO_MASK,                7
        .lclequ L_R_MASK,                       0xc0
        .lclequ AMS_PMS_MASK,                   0x37
        .lclequ OP1_BIT, 1
        .lclequ OP2_BIT, 4
        .lclequ OP3_BIT, 2
        .lclequ OP4_BIT, 8

        ;; getters for FM state
        .lclequ NOTE,(state_fm_note_semitone-state_fm)
        .lclequ NOTE_SEMITONE,(state_fm_note_semitone-state_fm)
        .lclequ DETUNE,(state_fm_detune-state_fm)
        .lclequ NOTE_POS16,(state_fm_note_pos16-state_fm)
        .lclequ NOTE_FNUM,(state_fm_note_fnum-state_fm)
        .lclequ NOTE_BLOCK,(state_fm_note_block-state_fm)
        .lclequ INSTRUMENT, (state_fm_instrument-state_fm)
        .lclequ OP1, (state_fm_op1_vol-state_fm)
        .lclequ OP2, (state_fm_op2_vol-state_fm)
        .lclequ OP3, (state_fm_op3_vol-state_fm)
        .lclequ OP4, (state_fm_op4_vol-state_fm)
        .lclequ OUT_OPS, (state_fm_out_ops-state_fm)
        .lclequ OUT_OP1, (state_fm_out_op1-state_fm)
        .lclequ VOL, (state_fm_vol-state_fm)

        ;; pipeline state for FM channel
        .lclequ STATE_PLAYING,      0x01
        .lclequ STATE_EVAL_MACRO,   0x02
        .lclequ STATE_LOAD_NOTE,    0x04
        .lclequ STATE_LOAD_VOL,     0x08
        .lclequ STATE_LOAD_REGS,    0x10
        .lclequ STATE_LOAD_ALL,     0x1e
        .lclequ STATE_CONFIG_VOL,   0x20
        .lclequ STATE_NOTE_STARTED, 0x80
        .lclequ BIT_PLAYING,        0
        .lclequ BIT_EVAL_MACRO,     1
        .lclequ BIT_LOAD_NOTE,      2
        .lclequ BIT_LOAD_VOL,       3
        .lclequ BIT_LOAD_REGS,      4
        .lclequ BIT_CONFIG_VOL,     5
        .lclequ BIT_NOTE_STARTED,   7


        .area  DATA

;;; FM playback state tracker
;;; ------

;;; write to the ym2610 port that matches the current context
ym2610_write_func:
        .blkb   3               ; space for `jp 0x....`

;;; Semitone F-num table in use (MVS or AES)
state_fm_note_f_num::
        .blkw   1

;;; Semitone half-distance table in use (MVS or AES)
state_fm_f_num_half_distance::
        .blkw   1

;;; context: current fm channel for opcode actions
_state_fm_start:
state_fm_channel::
        .blkb   1
state_fm_ym2610_channel::
        .blkb   1

;;; FM mirrored state
state_fm:
;;; FM1
state_fm1:
state_fm_pipeline:              .blkb   1       ; actions to run at every tick (load note, vol, other regs)
state_fm_fx:                    .blkb   1       ; enabled FX for this channel
;;; FX state trackers
state_fm_trigger:               .blkb   TRIGGER_SIZE
state_fm_fx_vol_slide:          .blkb   VOL_SLIDE_SIZE
state_fm_fx_slide:              .blkb   SLIDE_SIZE
state_fm_fx_vibrato:            .blkb   VIBRATO_SIZE
;;; FM-specific state
;;; Note
state_fm_note:
state_fm_instrument:            .blkb    1      ; instrument
state_fm_note_semitone:         .blkb    1      ; NSS note (octave+semitone) to be played on the FM channel
state_fm_detune:                .blkb    2      ; channel's fixed-point semitone detune
state_fm_note_pos16:            .blkb    2      ; channel's fixed-point note after the FX pipeline
state_fm_note_fnum:             .blkb    2      ; channel's f-num after the FX pipeline
state_fm_note_block:            .blkb    1      ; channel's FM block (multiplier) after the FX pipeline
;; volume
state_fm_vol:                   .blkb    1      ; configured note volume (attenuation)
state_fm_op1_vol:               .blkb    1      ; configured volume for OP1
state_fm_op2_vol:               .blkb    1      ; configured volume for OP2
state_fm_op3_vol:               .blkb    1      ; configured volume for OP3
state_fm_op4_vol:               .blkb    1      ; configured volume for OP4
state_fm_out_ops:               .blkb    1      ; bitmask of output OPs based on the configured FM algorithm
state_fm_out_op1:               .blkb    1      ; ym2610 volume for OP1 after the FX pipeline
state_fm_out_op2:               .blkb    1      ; ym2610 volume for OP2 after the FX pipeline
state_fm_out_op3:               .blkb    1      ; ym2610 volume for OP3 after the FX pipeline
state_fm_out_op4:               .blkb    1      ; ym2610 volume for OP4 after the FX pipeline
;;;
state_fm_end:
;;; FM2
state_fm2:
.blkb   FM_STATE_SIZE
;;; FM3
state_fm3:
.blkb   FM_STATE_SIZE
;;; FM4
state_fm4:
.blkb   FM_STATE_SIZE


;;; current pan (and instrument's AMS PMS) per FM channel
;;; TODO move to the state struct
state_pan_ams_pms::                  .blkb  4

;;; Global volume attenuation for all FM channels
state_fm_volume_attenuation::        .blkb   1

_state_fm_end:


        .area  CODE


;;; context: channel action functions for FM
state_fm_action_funcs:
        .dw     fm_configure_note_on
        .dw     fm_configure_vol
        .dw     fm_stop_playback


;;;  Reset FM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_fm_state_tracker::
        ld      hl, #_state_fm_start
        ld      d, h
        ld      e, l
        inc     de
        ;; zero state up to instr, which has a different init state
        ld      (hl), #0
        ld      bc, #state_pan_ams_pms-_state_fm_start
        ldir
        ;; pan has L and R enabled by default (0xc0)
        ld      (hl), #0xc0
        ld      bc, #3
        ldir
        ;; init instr to a non-existing instr (0xff)
        ld      a, #0xff
        ld      hl, #(state_fm+INSTRUMENT)
        ld      bc, #FM_STATE_SIZE
        ld      (hl), a
        add     hl, bc
        ld      (hl), a
        add     hl, bc
        ld      (hl), a
        add     hl, bc
        ld      (hl), a
        ;; global FM volume is initialized in the volume state tracker
        ;; init YM2610 function pointer
        ld      a, #0xc3        ; jp 0x....
        ld      (ym2610_write_func), a
        call    fm_ctx_reset
        ret


;;;  Reset FM playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
fm_ctx_reset::
        ld      a, #0
        call    fm_ctx_set_current
        ret


;;; Set the current FM track and YM2610 load function for this track
;;; ------
;;;   a : FM channel
fm_ctx_set_current::
        ;; set FM context
        ld      (state_fm_channel), a

        ;; set FM struct pointer for context
        ld      ix, #state_fm
        push    bc
        bit     0, a
        jr      z, _fm_ctx_post_bit0
        ld      bc, #FM_STATE_SIZE
        add     ix, bc
_fm_ctx_post_bit0:
        bit     1, a
        jr      z, _fm_ctx_post_bit1
        ld      bc, #FM_STATE_SIZE*2
        add     ix, bc
_fm_ctx_post_bit1:
        pop     bc

        ;; set YM2610 channel value for context
        cp      #2
        jp      c, _ctx_no_2
        add     #2
_ctx_no_2:
        inc     a
        ld      (state_fm_ym2610_channel), a

        ;; target the right YM2610 port (ch0,ch1: A, ch2,ch3: B)
        ld      a, (state_fm_channel)
        cp      #2
        jr      c, _fm_ctx_12
        ld      a, #<ym2610_write_port_b
        ld      (ym2610_write_func+1), a
        ld      a, #>ym2610_write_port_b
        ld      (ym2610_write_func+2), a
        ret
_fm_ctx_12:
        ld      a, #<ym2610_write_port_a
        ld      (ym2610_write_func+1), a
        ld      a, #>ym2610_write_port_a
        ld      (ym2610_write_func+2), a
        ret


;;; Configure the current FM channel's note frequency
;;; ------
;;;   hl : base frequency (f_num)
;;;    c : block (multiplier)
;;; [bc modified]
fm_set_fnum_registers::
        ;; configure REG_FMx_BLOCK_FNUM_2
        ;; this is buffered by the YM2610 and must be set
        ;; before setting REG_FMx_FNUM_1
        ;; c: block | f_num MSB
        ld      a, h
        or      c
        ld      c, a
        ;; a: FM channel (bit 0)
        ld      a, (state_fm_channel)
        res     1, a
        add     #REG_FM1_BLOCK_FNUM_2
        ld      b, a
        call    ym2610_write_func

        ;; configure REG_FMx_FNUM_1
        ld      a, b
        sub     #4
        ld      b, a
        ;; c: f_num LSB
        ld      c, l
        call    ym2610_write_func
        ret


;;; FM NSS opcodes
;;; ------

;;; FM_CTX_1
;;; Set the current FM track to be FM1 for the next FM opcode processing
;;; ------
fm_ctx_1::
        ld      a, #0
        call    fm_ctx_set_current
        ld      a, #1
        ret


;;; FM_CTX_2
;;; Set the current FM track to be FM2 for the next FM opcode processing
;;; ------
fm_ctx_2::
        ld      a, #1
        call    fm_ctx_set_current
        ld      a, #1
        ret


;;; FM_CTX_3
;;; Set the current FM track to be FM3 for the next FM opcode processing
;;; ------
fm_ctx_3::
        ld      a, #2
        call    fm_ctx_set_current
        ld      a, #1
        ret


;;; FM_CTX_4
;;; Set the current FM track to be FM4 for the next FM opcode processing
;;; ------
fm_ctx_4::
        ld      a, #3
        call    fm_ctx_set_current
        ld      a, #1
        ret


;;; output OPs based on the layout of each FM algorithm of the YM2610
;;;  7   6   5   4   3   2   1   0
;;; ___ ___ ___ ___ OP4 OP2 OP3 OP1
fm_out_ops_table:
        .db     0x8             ; algo 0: [1000] OP4
        .db     0x8             ; algo 1: [1000] OP4
        .db     0x8             ; algo 2: [1000] OP4
        .db     0x8             ; algo 3: [1000] OP4
        .db     0xc             ; algo 4: [1100] OP4, OP2
        .db     0xe             ; algo 5: [1110] OP4, OP2, OP3
        .db     0xe             ; algo 6: [1110] OP4, OP2, OP3
        .db     0xf             ; algo 7: [1111] OP4, OP2, OP3, OP1


;;; Configure the output OPs on an instrument's data
;;; ------
;;; hl: instrument address
;;; modified: hl, bc
fm_set_out_ops_bitfield::
        push    iy
        push    hl
        ;; iy: address of instrument data
        pop     iy

        ;; a: algo
        ld      a, INSTR_FB_ALGO_OFFSET(iy)
        and     #INSTR_ALGO_MASK

        ;; hl: bitmask address for algo
        ld      hl, #fm_out_ops_table
        ld      c, a
        ld      b, #0
        add     hl, bc

        ;; set out OPs bitmask for current channel
        ld      a, (hl)
        ld      OUT_OPS(ix), a

        pop     iy
        ret


;;; Update the current state's output level for all OPs based on an instrument
;;; ------
;;; ix: state for the current channel
;;; hl: address of the instrument's data
;;; [hl, iy modified]
fm_set_ops_level::
        push    hl
        pop     iy

        ;; set base OP levels from instruments
        ld      a, INSTR_TL_OFFSET(iy)
        ld      OP1(ix), a
        ld      a, INSTR_TL_OFFSET+1(iy)
        ld      OP2(ix), a
        ld      a, INSTR_TL_OFFSET+2(iy)
        ld      OP3(ix), a
        ld      a, INSTR_TL_OFFSET+3(iy)
        ld      OP4(ix), a

        ld      a, INSTR_FB_ALGO_OFFSET(iy)
        and     #INSTR_ALGO_MASK

        ;; hl: bitmask address for algo
        ld      hl, #fm_out_ops_table
        ld      c, a
        ld      b, #0
        add     hl, bc

        ;; set out OPs bitmask for current channel
        ld      a, (hl)
        ld      OUT_OPS(ix), a

        ret


;;; Compute fixed-point note position after FX-pipeline
;;; ------
;;; ix: state for the current channel
compute_fm_fixed_point_note::
        ;; hl: note from currently configured note (fixed point)
        ld      a, #0
        ld      l, a
        ld      h, NOTE_SEMITONE(ix)

        ;; hl: detuned semitone
        ld      c, DETUNE(ix)
        ld      b, DETUNE+1(ix)
        add     hl, bc

        ;; bc: slide offset if the slide FX is enabled
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _fm_post_add_slide
        ld      c, SLIDE_POS16(ix)
        ld      b, SLIDE_POS16+1(ix)
        add     hl, bc
_fm_post_add_slide::

        ;; bc vibrato offset if the vibrato FX is enabled
        bit     BIT_FX_VIBRATO, FX(ix)
        jr      z, _fm_post_add_vibrato
        ld      c, VIBRATO_POS16(ix)
        ld      b, VIBRATO_POS16+1(ix)
        add     hl, bc
_fm_post_add_vibrato::

        ;; update computed fixed-point note position
        ld      NOTE_POS16(ix), l
        ld      NOTE_POS16+1(ix), h
        ret


;;; Compute the YM2610's volume registers value from the OP's volumes
;;; ------
;;; modified: bc, de, hl
compute_ym2610_fm_vol::
        push    iy

        ;; a: note vol (attenuation) for current channel
        ld      a, VOL(ix)
        bit     BIT_FX_VOL_SLIDE, FX(ix)
        jr      z, _vol_post_clamp_up
        ;; add slide down vol and clamp
        add     VOL_SLIDE_POS16+1(ix)
        bit     7, a
        jr      z, _vol_post_clamp_up
        ld      a, #127
_vol_post_clamp_up:
        ;; b: intermediate attenuation (note vol + vol slide)
        ld      b, a

        ;; c: bitmask for the output OPs + sentinel bits for looping
        ld      a, OUT_OPS(ix)
        or      #0xF0           ; 4 bits => 4 total loads (1 load per OP).
        ld      c, a

        ;; hl: address of instrument's ops volumes
        push    ix
        pop     hl
        ld      de, #OP1
        add     hl, de

        ;; iy: address of computed volumes for ops register (8bit aligned add)
        push    ix
        pop     iy
        ld      d, #0
        ld      e, #OUT_OP1
        add     iy, de

_c_ops_loop:
        ;; a: OP level
        ld      a, (hl)
        inc     hl

        ;; check whether OP is an output
        bit     0, c
        jr      z, _c_ops_result

        ;; if so, subtract intermediate volume (attenuation)
        add     b
        bit     7, a
        jr      z, _c_ops_post_clamp
        ld      a, #127
_c_ops_post_clamp:

        ;; substract global volume attenuation
        ;; NOTE: YM2610's FM output level ramp follows an exponential curve,
        ;; so we implement this output level attenuation via a basic
        ;; addition, clamped to 127 (max attenuation).
        ld      d, a
        ld      a, (state_fm_volume_attenuation)
        add     d
        bit     7, a
        jr      z, _c_ops_post_global_clamp
        ld      a, #127
_c_ops_post_global_clamp:

_c_ops_result:
        ;; saved configured OP value
        ld      (iy), a
        inc     iy
_c_ops_next:
        srl     c
        bit     4, c
        jr      nz, _c_ops_loop

        pop     iy

        ret


;;; Compute the YM2610's note registers value from state's fixed-point note
;;; ------
;;; modified: bc, de, hl
compute_ym2610_fm_note::
        ;; b: current note (integer part)
        ld      l, NOTE_POS16+1(ix)

        ;; c: octave and semitone from note
        ld      h, #>note_to_octave_semitone
        ld      c, (hl)

        ;; configure block
        ld      a, c
        and     #0xf0
        sra     a
        ld      NOTE_BLOCK(ix), a

        ;; c: semitone
        ld      a, c
        and     #0xf
        ld      c, a

        ;; push base floating point tune for note (24bits)
        ;; de:b : base f-num for note
        ld      hl, #fm_fnums
        add     c
        add     c
        add     l
        ld      l, a
        ld      b, (hl)
        inc     l
        ld      e, (hl)
        inc     l
        ld      d, (hl)
        push    bc              ; +base F-num __:8_
        push    de              ; +base F-num 16:__

        ;; prepare arguments for scaling distance to next tune
        ;; c:de: distance to next f-num for note
        ld      hl, #fm_dists
        ld      a, c
        add     c
        add     c
        add     l
        ld      l, a
        ld      e, (hl)
        inc     l
        ld      d, (hl)
        inc     l
        ld      c, (hl)

        ;; l: current note (fractional part) to offset in delta table
        ;; l/2 to get index in delta table
        ;; (l/2)*2 to get offset in bytes in the delta table
        ld      l, NOTE_POS16(ix)
        res     0, l

        ;; hl: delta factor for current fractional part
        ld      h, #>fm_fnum_deltas
        ld      b, (hl)
        inc     l
        ld      h, (hl)
        ld      l, b

        ;; de:b : scaled 24bit distance
        call    scale_int24_by_factor16

        ;; hl:a_ : base F-num
        pop     hl              ; -base tune 16:__
        pop     af              ; -base tune __:8_

        ;; final tune = base tune + result = hl:a_ + de:b_
        add     b
        adc     hl, de

        ;; hl: SSG final tune = hl >> 3
        ld      a, l
        srl     h
        rra
        srl     h
        rra
        srl     h
        rra
        srl     h
        rra
        ld      l, a

        ld      NOTE_FNUM(ix), l
        ld      NOTE_FNUM+1(ix), h

        ret


;;; run_fm_pipeline
;;; ------
;;; Run the entire FM pipeline once. for each FM channels:
;;;  - update the state of all enabled FX
;;;  - load specific parts of the state (note, vol...) into YM2610 registers
;;; Meant to run once per tick
run_fm_pipeline::
        push    de
        push    iy
        push    ix

        ;; we loop though every channel during the execution,
        ;; so save the current channel context
        ld      a, (state_fm_channel)
        push    af

        ;; update state of all FM channels, starting from FM1
        xor     a
_fm_update_loop:
        call    fm_ctx_set_current

        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        cp      #0
        jp      z, _end_fm_channel_pipeline

        ;; Pipeline action: evaluate one FX step for each enabled FX

        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _fm_post_fx_trigger
        ld      hl, #state_fm_action_funcs
        call    eval_trigger_step
_fm_post_fx_trigger:
        bit     BIT_FX_VIBRATO, FX(ix)
        jr      z, _fm_post_fx_vibrato
        call    eval_fm_vibrato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_post_fx_vibrato:
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _fm_post_fx_slide
        ld      hl, #NOTE_SEMITONE
        call    eval_fm_slide_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_post_fx_slide:
        bit     BIT_FX_VOL_SLIDE, FX(ix)
        jr      z, _fm_post_fx_vol_slide
        call    eval_vol_slide_step
        set     BIT_LOAD_VOL, PIPELINE(ix)
_fm_post_fx_vol_slide:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _fm_post_check_playing
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_post_check_playing:

        ;; Pipeline action: load volume registers when the volume state is modified
        bit     BIT_LOAD_VOL, PIPELINE(ix)
        jr      z, _post_load_fm_vol
        res     BIT_LOAD_VOL, PIPELINE(ix)

        call    compute_ym2610_fm_vol

        ;; hl: OPs volume data
        push    ix
        pop     hl
        ld      bc, #OUT_OP1
        add     hl, bc

        ;; b: OP1 start register in YM2610 for current channel
        ld      a, (state_fm_channel)
        res     1, a
        add     #REG_FM1_OP1_TOTAL_LEVEL
        ld      b, a

        ;; load all OPs volumes
        ld      d, #4
fm_vol_load_loop:
        ld      c, (hl)
        call    ym2610_write_func
        dec     d
        jr      z, _post_load_fm_vol
        inc     hl
        ld      a, b
        add     a, #NSS_FM_NEXT_REGISTER
        ld      b, a
        jr      fm_vol_load_loop
_post_load_fm_vol:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      z, _post_load_fm_note
        res     BIT_LOAD_NOTE, PIPELINE(ix)

        call    compute_fm_fixed_point_note
        call    compute_ym2610_fm_note

        ;; reload computed note
        ld      l, NOTE_FNUM(ix)
        ld      h, NOTE_FNUM+1(ix)
        ld      c, NOTE_BLOCK(ix)
        call    fm_set_fnum_registers

        ;; start current FM channel (enable all OPs) if not already done
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _post_load_fm_note
        ld      a, (state_fm_ym2610_channel)
        or      #0xf0
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a
        set     BIT_NOTE_STARTED, PIPELINE(ix)
_post_load_fm_note:

_end_fm_channel_pipeline:
        ;; next context
        ld      a, (state_fm_channel)
        inc     a
        cp      #4
        jr      nc, _fm_end_pipeline
        jp      _fm_update_loop

_fm_end_pipeline:
        ;; restore the real channel context
        pop     af
        call    fm_ctx_set_current

        pop     ix
        pop     iy
        pop     de
        ret


;;; FM_VOL
;;; Register a pending volume change for the current FM channel
;;; The next note to be played or instrument change will pick
;;; up this volume configuration change
;;; ------
;;; [ hl ]: volume [0-127]
fm_vol::
        ;; a: volume (difference from max volume)
        ld      a, #127
        sub     (hl)
        inc     hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _fm_vol_immediate
        ld      TRIGGER_VOL(ix), a
        set     BIT_TRIGGER_LOAD_VOL, TRIGGER_ACTION(ix)
        jr      _fm_vol_end

_fm_vol_immediate:
        ;; else load vol immediately
        call    fm_configure_vol

_fm_vol_end:
        ld      a, #1
        ret


;;; FM_INSTRUMENT
;;; Configure the operators of an FM channel based on an instrument's data
;;; ------
;;; [ hl ]: instrument number
fm_instrument::
        ;; a: instrument
        ld      a, (hl)
        inc     hl

        push    bc
        push    hl
        push    de

        ;; if the current instrument for channel is not updated, bail out
        ld      b, INSTRUMENT(ix)
        cp      b
        jp      z, _fm_instr_end

        ;; else recall new instrument for channel
        ld      INSTRUMENT(ix), a

        ;; stop current FM channel (disable all OPs)
        ;; TODO move that to the pipeline?
        push    af

        ld      a, (state_fm_ym2610_channel)
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        ;; b: fm channel
        ld      a, (state_fm_channel)
        ld      b, a

        pop     af

        ;; hl: instrument address in ROM
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
        push    hl              ; +instrument address

        ;; d: all FM properties
        ld      d, #NSS_FM_INSTRUMENT_PROPS

        ;; b: fm channel
        ld      a, (state_fm_channel)
        ld      b, a

        ;; a: start register in YM2610 for FM channel
        ld      a, #REG_FM1_OP1_DETUNE_MULTIPLY
        res     1, b
        add     b
_fm_port_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_func
        add     a, #NSS_FM_NEXT_REGISTER
        inc     hl
        dec     d
        jp      nz, _fm_port_loop
        ;;
        ld      d, #NSS_FM_END_OF_REGISTERS
        cp      d
        jp      nc, _fm_end
        ;; two additional properties a couples of regs away
        add     a, #NSS_FM_NEXT_REGISTER_GAP
        ld      d, #1
        jp      _fm_port_loop

_fm_end:
        ;; set the pan, AMS and PMS settings for this instrument
        call    fm_set_pan_ams_pms
        ;; set the state's output OPs from this instrument
        pop     hl              ; -instrument address
        call    fm_set_ops_level

        set     BIT_LOAD_VOL, PIPELINE(ix)

        ;; setting a new instrument always trigger a note start,
        ;; register it for the next pipeline run
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        set     BIT_LOAD_NOTE, PIPELINE(ix)

_fm_instr_end:
        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; fm_set_pan_ams_pms
;;; set the AMS and PMS settings for this instrument,
;;; augmented with the current pan config for the channel
;;; ------
;;;    a  : value for the AMS/PMS register
;;; [ hl ]: AMS/PMS instrument data
fm_set_pan_ams_pms::
        ;; b: ams/pms register
        ld      b, a

        ;; [de]: pan for channel (8bit add)
        ld      de, #state_pan_ams_pms
        ld      a, (state_fm_channel)
        add     a, e
        ld      e, a

        ;; update state's pan AMS/PMS for channel
        ld      a, (de)
        and     #L_R_MASK
        ld      c, a
        ld      a, (hl)
        and     #AMS_PMS_MASK
        add     c
        ld      (de), a

        ;; update YM2610's pan AMS/PMS for channel
        ld      c, a
        ld      a, b
        call    ym2610_write_func

        ret


;;; build the 16bit signed detune displacement
;;; ------
;;; IN
;;;   [ hl ]: detune
;;; OUT:
;;;     bc  : 16bits signed displacement
;;; bc, hl modified
common_pitch::
        ;; a: detune [0..255]
        ld      a, (hl)
        inc     hl

        ;; bc: detune [-128..127]
        sub     #0x80
        ld      c, a
        add     a, a
        sbc     a
        ld      b, a

        ;; bc: 2*detune, semitone range in ]-1..1[
        push    hl
        ld      hl, #0
        add     hl, bc
        add     hl, bc
        ld      b, h
        ld      c, l
        pop     hl

        ld      a, #1
        ret


;;; FM_PITCH
;;; Detune up to -+1 semitone for the current FM channel
;;; ------
;;; [ hl ]: detune
fm_pitch::
        push    bc
        call    common_pitch
        ld      DETUNE(ix), c
        ld      DETUNE+1(ix), b
        pop     bc
        ld      a, #1
        ret


;;; Update the vibrato for the current FM channel
;;; ------
;;; ix: mirrored state of the current fm channel
eval_fm_vibrato_step::
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
eval_fm_slide_step::
        push    hl
        push    de
        push    bc
        ;; push    ix

        ;; update internal state for the next slide step
        call    eval_slide_step

        ;; effect still in progress?
        cp      a, #0
        jp      nz, _end_fm_slide_load_fnum2
        ;; otherwise set the end note as the new base note
        ld      a, NOTE(ix)
        add     d
        ld      NOTE(ix), a
_end_fm_slide_load_fnum2:

        ;; pop     ix
        pop     bc
        pop     de
        pop     hl

        ret


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
fm_configure_note_on:
        push    bc
        push    af              ; +note
        ;; if portamento is ongoing, this is treated as an update
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _fm_cfg_note_update
        ld      a, SLIDE_PORTAMENTO(ix)
        cp      #0
        jr      z, _fm_cfg_note_update
        ;; update the portamento now
        pop     af              ; -note
        ld      SLIDE_PORTAMENTO(ix), a
        ld      b, NOTE_SEMITONE(ix)
        call    slide_portamento_finish_init
        ;; if a note is currently playing, do nothing else, the
        ;; portamento will be updated at the next pipeline run...
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _fm_cfg_note_end
        ;; ... else a new instrument was loaded, reload this note as well
        jr      _fm_cfg_note_prepare_ym2610
_fm_cfg_note_update:
        ;; update the current note and prepare the ym2610
        pop     af              ; -note
        ld      NOTE_SEMITONE(ix), a
_fm_cfg_note_prepare_ym2610:
        ;; stop playback on the channel, and let the pipeline restart it
        ld      a, (state_fm_ym2610_channel)
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        ld      a, PIPELINE(ix)
        or      #(STATE_PLAYING|STATE_EVAL_MACRO|STATE_LOAD_NOTE)
        ld      PIPELINE(ix), a
_fm_cfg_note_end:
        pop     bc

        ret


;;; Configure state for new volume and trigger a load in the pipeline
;;; ------
fm_configure_vol:
        ld      VOL(ix), a

        ;; reload configured vol at the next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)

        ret


;;; FM_NOTE_ON
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm_note_on::
        ;; a: note (0xAB: A=octave B=semitone)
        ld      a, (hl)
        inc     hl

        ;; delay load via the trigger FX?
        bit     BIT_TRIGGER_ACTION_DELAY, TRIGGER_ACTION(ix)
        jr      z, _fm_note_on_immediate
        ld      TRIGGER_NOTE(ix), a
        set     BIT_TRIGGER_LOAD_NOTE, TRIGGER_ACTION(ix)
        jr      _fm_note_on_end

_fm_note_on_immediate:
        ;; else load note immediately
        call    fm_configure_note_on

_fm_note_on_end:
        ;; fm context will now target the next channel
        ld      a, (state_fm_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; FM_NOTE_ON_AND_WAIT
;;; Emit a specific note (frequency) on an FM channel and
;;; immediately wait as many rows as the last wait
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm_note_on_and_wait::
        ;; process a regular note opcode
        call    fm_note_on

        ;; wait rows
        call    wait_last_rows
        ret


;;; Release the note on an FM channel and update the pipeline state
;;; ------
fm_stop_playback:
        ;; stop all OPs of FM channel
        push    bc
        ld      a, (state_fm_ym2610_channel)
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a
        pop     bc

        ;; disable playback in the pipeline, any load_note bit
        ;; will get cleaned during the next pipeline run
        res     BIT_PLAYING, PIPELINE(ix)

        ;; record that playback is stopped
        xor     a
        res     BIT_NOTE_STARTED, PIPELINE(ix)

        ret


;;; FM_NOTE_OFF
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
fm_note_off::
        call    fm_stop_playback

        ;; FM context will now target the next channel
        ld      a, (state_fm_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; OP1_LVL
;;; Set the volume of OP1 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op1_lvl::
        ld      a, (hl)
        inc     hl
        ld      OP1(ix), a
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; OP2_LVL
;;; Set the volume of OP2 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op2_lvl::
        ld      a, (hl)
        inc     hl
        ld      OP2(ix), a
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; OP3_LVL
;;; Set the volume of OP3 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op3_lvl::
        ld      a, (hl)
        inc     hl
        ld      OP3(ix), a
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; OP4_LVL
;;; Set the volume of OP4 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op4_lvl::
        ld      a, (hl)
        inc     hl
        ld      OP4(ix), a
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; FM_VIBRATO
;;; Enable vibrato for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_vibrato::
        ;; TODO: move this part to common vibrato_init

        ;; hl == 0 means disable vibrato
        ld      a, (hl)
        cp      #0
        jr      nz, _setup_fm_vibrato

        ;; disable vibrato fx
        res     BIT_FX_VIBRATO, FX(ix)

        ;; reload configured note at the next pipeline run
        set     BIT_LOAD_NOTE, PIPELINE(ix)

        inc     hl
        jr      _post_fm_vibrato_setup

_setup_fm_vibrato:
        call    vibrato_init

_post_fm_vibrato_setup:

        ld      a, #1
        ret


;;; FM_NOTE_SLIDE_UP
;;; Enable slide up effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_note_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE_SEMITONE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; FM_NOTE_SLIDE_DOWN
;;; Enable slide down effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_note_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE_SEMITONE
        call    slide_init
        ld      a, #1
        pop     bc
        ret


;;; FM_PITCH_SLIDE_UP
;;; Enable slide up effect for the current FM channel
;;; ------
;;; [ hl ]: speed (8bits)
fm_pitch_slide_up::
        push    bc
        ld      b, #0
        ld      c, #NOTE_SEMITONE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; FM_PITCH_SLIDE_DOWN
;;; Enable slide down effect for the current FM channel
;;; ------
;;; [ hl ]: speed (8bits)
fm_pitch_slide_down::
        push    bc
        ld      b, #1
        ld      c, #NOTE_SEMITONE
        call    slide_pitch_init
        ld      a, #1
        pop     bc
        ret


;;; FM_PORTAMENTO
;;; Enable slide to the next note to be loaded into the pipeline
;;; ------
;;; [ hl ]: speed
fm_portamento::
        ;; current note (start of portamento)
        ld      a, NOTE_POS16+1(ix)

        call    slide_portamento_init

        ld      a, #1
        ret


;;; FM_PAN
;;; Enable left/right output for the current FM channel
;;; ------
;;; [ hl ]: pan mask (0x01: left, 0x10: right)
fm_pan::
        push    de
        push    bc

        ;; c: pan mask
        ld      c, (hl)
        inc     hl

        ;; b: current channel
        ld      a, (state_fm_channel)
        ld      b, a

        ;; de: pan AMS/PMS for channel (8bit add)
        ld      de, #state_pan_ams_pms
        add     a, e
        ld      e, a

        ;; update state's pan AMS/PMS for channel
        ld      a, (de)
        and     #AMS_PMS_MASK
        add     c
        ld      (de), a

        ;; update YM2610's pan AMS/PMS for channel
        ld      c, a
        ld      a, #REG_FM1_L_R_AMSENSE_PMSENSE
        res     1, b
        add     b
        ld      b, a
        call    ym2610_write_func

        pop     bc
        pop     de
        ld      a, #1
        ret


;;; FM_VOL_SLIDE_DOWN
;;; Enable volume slide down effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits)
fm_vol_slide_down::
        push    bc
        push    de

        ld      bc, #0x40
        ld      d, #127
        ld      a, #1
        call    vol_slide_init

        pop     de
        pop     bc

        ld      a, #1
        ret


;;; FM_DELAY
;;; Enable delayed trigger for the next note and volume
;;; (note and volume and played after a number of ticks)
;;; ------
;;; [ hl ]: delay
fm_delay::
        call    trigger_delay_init

        ld      a, #1
        ret


;;; FM_CUT
;;; Record that the note being played must be stopped after some steps
;;; ------
;;; [ hl ]: delay
fm_cut::
        call    trigger_cut_init

        ld      a, #1
        ret
