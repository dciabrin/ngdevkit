;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024-2026 Damien Ciabrini
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

        .include "align.inc"
        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"

        .lclequ FM_CHANNEL_STATE_SIZE,(state_fm_channel_state_end-state_fm_channel_state_start)
        .lclequ FM_YM2610_STATE_SIZE,(state_fm_ym2610_state_end-state_fm_ym2610_state_start)
        .lclequ FM_YM2610_OP_STATE_SIZE,(state_fm_ym2610_op_state_end-state_fm_ym2610_op_state_start)
        .lclequ FM_MAX_VOL,0x7f

        ;; FM constants
        .lclequ NSS_OP_INSTRUMENT_PROPS,        7
        .lclequ NSS_OP_NEXT_REGISTER,           16
        .lclequ NSS_FM_INSTRUMENT_PROPS,        28
        .lclequ NSS_FM_OPS_PROPS,               4
        .lclequ NSS_FM_KS_AR_TO_SSG_PROPS,      20
        .lclequ NSS_FM_NEXT_REGISTER,           4
        .lclequ NSS_FM_NEXT_REGISTER_GAP,       16
        .lclequ NSS_FM_END_OF_REGISTERS,        0xb3
        .lclequ INSTR_TL_OFFSET,                30
        .lclequ INSTR_FB_ALGO_OFFSET,           28
        .lclequ INSTR_ALGO_MASK,                7
        .lclequ L_R_MASK,                       0xc0
        .lclequ AMS_PMS_MASK,                   0x37
        ;; FM channel offset, in YM2610 order
        .lclequ FM1_YM2610,                     1
        .lclequ FM2_YM2610,                     2
        .lclequ FM3_YM2610,                     5
        .lclequ FM4_YM2610,                     6
        ;; OPs offset, in YM2610 order
        .lclequ OP1_OFFSET,                     0
        .lclequ OP2_OFFSET,                     2
        .lclequ OP3_OFFSET,                     1
        .lclequ OP4_OFFSET,                     3

        ;; getters for FM state
        .lclequ DETUNE,(state_fm_detune-state_fm)
        .lclequ NOTE_POS16,(state_fm_note_pos16-state_fm)
        .lclequ NOTE_FNUM,(state_fm_note_fnum-state_fm)
        .lclequ NOTE_BLOCK,(state_fm_note_block-state_fm)
        .lclequ INSTRUMENT, (state_fm_instrument-state_fm)
        ;; OP volumes as configured by the instrument
        .lclequ OP1, (state_fm_op1_vol-state_fm)
        .lclequ OP2, (state_fm_op2_vol-state_fm)
        .lclequ OP3, (state_fm_op3_vol-state_fm)
        .lclequ OP4, (state_fm_op4_vol-state_fm)
        .lclequ OPS_ENABLED, (state_fm_ops_enabled-state_fm)
        ;; OP volumes after the FM pipeline is executed for a tick
        .lclequ OUT_OPS, (state_fm_out_ops-state_fm)
        .lclequ OUT_OP1, (state_fm_out_op1-state_fm)
        .lclequ OUT_OP2, (state_fm_out_op2-state_fm)
        .lclequ OUT_OP3, (state_fm_out_op3-state_fm)
        .lclequ OUT_OP4, (state_fm_out_op4-state_fm)
        .lclequ OP_TO_OUT_OP, (state_fm_out_op1-state_fm_op1_vol)


        .area  DATA


;;; FM playback state tracker
;;; ------

;;; write to the ym2610 port that matches the current context
;;; enough byte space for generated code `jp 0x....`
ym2610_write_func:              .blkb   3

;;; Semitone F-num table in use (MVS or AES)
state_fm_note_f_num::           .blkw   1

;;; Semitone half-distance table in use (MVS or AES)
state_fm_f_num_half_distance::  .blkw   1

;;; context: current fm channel for opcode actions
state_fm_channel::              .blkb   1

;;; context: current fm channel in YM2610 notation
state_fm_ym2610_channel::       .blkb   1

;;; context: pointer to the current FM pipeline
;;; (only used by fm_note_on right now, check if we can get rid of this)
state_fm_channel_pipeline::     .blkw   1

;;; context: current feedback register value for the current FM channel
;;; NOTE: in an effort to replicate Furnace semantics, the same feedback
;;; value seems to be used for all OP when using extended FM2
state_fm_fm2_fb::               .blkb   1

;;; context: OP currently processed by the OP pipeline
state_fm_ym2610_op::            .blkb   1

;;; context: OP mask to use with ON/OFF register for the current FM channel
state_fm_ym2610_op_mask::       .blkb   1

;;; context: Fnum-2 register in use for the current FM channel
state_fm_fnum2_reg::            .blkb   1

;;; context: volume register in use for the OP currently processed
state_fm_op_tl_reg::            .blkb   1


;;; FM1 state tracker
.align_begin state_fm1
;;; { ...
state_fm1:

;;; General state for all FM channels except FM2 when used with extended OP
state_fm_channel_state_start:
;;; note state tracker
state_fm_note_cfg:              .blkb   1      ; configured note
state_fm_note16:                .blkb   2      ; current decimal note
;;; note FX state tracker
state_fm_note_fx:               .blkb   1      ; enabled note FX
state_fm_fx_note_slide:         .blkb   SLIDE_SIZE
state_fm_fx_vibrato:            .blkb   VIBRATO_SIZE
state_fm_fx_arpeggio:           .blkb   ARPEGGIO_SIZE
state_fm_fx_legato:             .blkb   LEGATO_SIZE
;;; volume state tracker
state_fm_vol_cfg:               .blkb   1      ; configured volume
state_fm_vol16:                 .blkb   2      ; current decimal volume
;;; common FX state tracker
state_fm_fx:                    .blkb   1      ; enabled FX
state_fm_fx_vol_slide:          .blkb   SLIDE_SIZE
state_fm_fx_trigger:            .blkb   TRIGGER_SIZE
state_fm_channel_state_end:

;;; actions to run at the end of every tick
state_fm:
state_fm1_pipeline:
state_fm_pipeline:              .blkb   1      ; action: load note, load vol, load other regs

;;; FM-specific YM2610 state tracker
state_fm_ym2610_state_start:
state_fm_ym2610_op_state_start:
;;; Note
;; state_fm_note:
state_fm_instrument:            .blkb    1      ; instrument
state_fm_detune:                .blkb    2      ; channel's fixed-point semitone detune
state_fm_note_pos16:            .blkb    2      ; channel's fixed-point note after the FX pipeline
state_fm_note_fnum:             .blkb    2      ; channel's f-num after the FX pipeline
state_fm_note_block:            .blkb    1      ; channel's FM block (multiplier) after the FX pipeline
state_fm_ym2610_op_state_end:
;; volume
state_fm_op1_vol:               .blkb    1      ; instrument volume for OP1
state_fm_op3_vol:               .blkb    1      ; instrument volume for OP3
state_fm_op2_vol:               .blkb    1      ; instrument volume for OP2
state_fm_op4_vol:               .blkb    1      ; instrument volume for OP4
state_fm_out_ops:               .blkb    1      ; bitmask of output OPs from instrument's FM algorithm
state_fm_out_op1:               .blkb    1      ; ym2610 volume for OP1 after the FX pipeline
state_fm_out_op3:               .blkb    1      ; ym2610 volume for OP3 after the FX pipeline
state_fm_out_op2:               .blkb    1      ; ym2610 volume for OP2 after the FX pipeline
state_fm_out_op4:               .blkb    1      ; ym2610 volume for OP4 after the FX pipeline
state_fm_ops_enabled:           .blkb    1      ; ym2610 OPs enabled for the current channel
state_fm_ym2610_state_end:

;;; ... }
.align_end state_fm1


;;; FM2 state tracker
;;; This is a bigger state tracker, where the channel state tracker part
;;; is duplicated for the four operators
.align_begin state_fm2
;;; { ...
state_fm2:
;;; OP1-specific channel state
                                .blkb   FM_CHANNEL_STATE_SIZE
state_op1_pipeline:             .blkb   1
                                .blkb   FM_YM2610_OP_STATE_SIZE
;;; OP2-specific channel state
                                .blkb   FM_CHANNEL_STATE_SIZE
state_op2_pipeline:             .blkb   1
                                .blkb   FM_YM2610_OP_STATE_SIZE
;;; OP3-specific channel state
                                .blkb   FM_CHANNEL_STATE_SIZE
state_op3_pipeline:             .blkb   1
                                .blkb   FM_YM2610_OP_STATE_SIZE
;;; OP4-specific channel state
                                .blkb   FM_CHANNEL_STATE_SIZE
state_op4_pipeline:             .blkb   1
                                .blkb   FM_YM2610_OP_STATE_SIZE
;;; FM2-specific channel state
                                .blkb   FM_CHANNEL_STATE_SIZE
state_fm2_pipeline:             .blkb   1
;;; FM-specific YM2610 state tracker
                                .blkb   FM_YM2610_STATE_SIZE
;;; ... }
.align_end state_fm2


;;; FM3 state tracker
;;; { ...
.align_begin state_fm3
state_fm3:
                                .blkb   FM_CHANNEL_STATE_SIZE
state_fm3_pipeline:             .blkb   1
                                .blkb   FM_YM2610_STATE_SIZE
;;; ... }
.align_end state_fm3


;;; FM4 state tracker
;;; { ...
.align_begin state_fm4
state_fm4:
                                .blkb   FM_CHANNEL_STATE_SIZE
state_fm4_pipeline:             .blkb   1
                                .blkb   FM_YM2610_STATE_SIZE
;;; ... }
.align_end state_fm4



;;; current pan (and instrument's AMS PMS) per FM channel
;;; TODO move to the state struct
state_pan_ams_pms::                  .blkb  4

;;; Global volume attenuation for all FM channels
state_fm_volume_attenuation::        .blkb   1



        .area  CODE


;;; context: channel action functions for FM
state_fm_action_funcs:
        .dw     fm_configure_note_on
        .dw     fm_configure_vol
        .dw     fm_stop_playback


;;;  Reset FM playback state.
;;;  Called before playing a stream
;;; ------
;;; bc, de, hl, iy modified
init_nss_fm_state_tracker::
        ld      hl, #(state_fm1_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_op1_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_op2_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_op3_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_op4_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_fm2_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_fm3_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state
        ld      hl, #(state_fm4_pipeline-FM_CHANNEL_STATE_SIZE)
        call    _fm_zero_channel_state

        ;; default ext FM2 Feedback
        ;; TODO: check in Furnace why this seems to be required
        ld      a, #0x40
        ld      (state_fm_fm2_fb), a
        ;; zero state up to instr, which has a different init state
        ;; pan has L and R enabled by default (0xc0)
        ld      hl, #state_pan_ams_pms
        ld      d, h
        ld      e, l
        inc     de
        ld      (hl), #0xc0
        ld      bc, #3
        ldir
        ;; init YM2610 function pointer
        ld      a, #0xc3        ; jp 0x....
        ld      (ym2610_write_func), a
        call    fm_ctx_reset
        ;; global FM volume is initialized in the volume state tracker
        ret


;;; reset a FM or OP pipeline state.
;;; ------
;;; hl: start of channel state (prior to FM/OP pipeline)
;;;
_fm_zero_channel_state::
        ;; clear data from start state to pipeline offset
        ld      d, h
        ld      e, l
        inc     de
        ld      bc, #FM_CHANNEL_STATE_SIZE-1
        ld      (hl), #0
        ldir
        ;; hl: pipeline offset
        inc     hl
        push    hl
        ;; default values for channel's state and FX
        pop     iy
        ld      NOTE_CTX+SLIDE_MAX(iy), #((8*12)-1) ; max note
        ld      VOL_CTX+SLIDE_MAX(iy), #FM_MAX_VOL ; max volume for channel
        ld      ARPEGGIO_SPEED(iy), #1   ; default arpeggio speed
        ld      INSTRUMENT(iy), #0xff    ; non-existing instrument
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
;;;   a : FM channel [0..3]
fm_ctx_set_current::
        push    hl

        ld      (state_fm_channel), a

        ;; hl: offset into ctx data (base + a*4)
        rlca
        rlca
        add     #<_fm_ctx_data
        ld      l, a
        ld      a, #0
        adc     #>_fm_ctx_data
        ld      h, a

        ;; set YM2610 channel value for context
        ld      a, (hl)
        ld      (state_fm_ym2610_channel), a

        ;; set FNum-2 YM2610 register for context
        inc     hl
        ld      a, (hl)
        ld      (state_fm_fnum2_reg), a

        ;; set all operators considered for this pipeline
        ld      a, #0xf0
        ld      (state_fm_ym2610_op_mask), a

        ;; ix: set pipeline context
        inc     hl
        ld      a, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a
        push    hl
        pop     ix
        ld      a, l
        ld      (state_fm_channel_pipeline), a
        ld      a, h
        ld      (state_fm_channel_pipeline+1), a

        pop     hl

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
_fm_ctx_data:
        .db     FM1_YM2610, REG_FM1_BLOCK_FNUM_2
        .dw     state_fm1_pipeline
        .db     FM2_YM2610, REG_FM2_BLOCK_FNUM_2
        .dw     state_fm2_pipeline
        .db     FM3_YM2610, REG_FM3_BLOCK_FNUM_2
        .dw     state_fm3_pipeline
        .db     FM4_YM2610, REG_FM4_BLOCK_FNUM_2
        .dw     state_fm4_pipeline


;;; a: OP number in YM2610 order (OP1: 0, OP2: 2, OP3:1, OP4:3)
;;; modified: bc, de, hl, ix, iy
fm_ctx_op_set_current::
        ld      (state_fm_ym2610_op), a

        ;; iy: FM2 pipeline (the only channel with extended OP)
        ld      iy, #state_fm2_pipeline

        ;; hl: offset in OP data from OP
        ld      b, #0
        ld      c, a
        ld      hl, #_fm_ctx_op_data
        add     hl, bc

        ;; Fnum-2 register for OP
        ld      a, (hl)
        ld      (state_fm_fnum2_reg), a

        ;; Total Level register for OP
        ld      de, #4
        add     hl, de
        ld      a, (hl)
        ld      (state_fm_op_tl_reg), a

        ;; OP mask for OP
        add     hl, de
        ld      a, (hl)
        ld      (state_fm_ym2610_op_mask), a

        ;; ix: pipeline for OP
        add     hl, de
        ld      a, (hl)
        add     hl, de
        ld      e, (hl)
        ld      d, a
        push    de
        pop     ix

        ret
_fm_ctx_op_data:
        .db     REG_FM2_OP1_BLOCK_FNUM_2, REG_FM2_OP3_BLOCK_FNUM_2, REG_FM2_OP2_BLOCK_FNUM_2, REG_FM2_OP4_BLOCK_FNUM_2
        .db     REG_FM2_OP1_TOTAL_LEVEL, REG_FM2_OP3_TOTAL_LEVEL, REG_FM2_OP2_TOTAL_LEVEL, REG_FM2_OP4_TOTAL_LEVEL
_fm_ctx_op_mask_data:
        .db     0x10, 0x40, 0x20, 0x80
_fm_ctx_op_pipeline_data:
        .db     >state_op1_pipeline, >state_op3_pipeline, >state_op2_pipeline, >state_op4_pipeline
        .db     <state_op1_pipeline, <state_op3_pipeline, <state_op2_pipeline, <state_op4_pipeline


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

        ;; a: REG_FMx_FNUM_2 for FM channel
        ld      a, (state_fm_fnum2_reg)
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
        ld      OP3(ix), a
        ld      a, INSTR_TL_OFFSET+2(iy)
        ld      OP2(ix), a
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


;;; Stop operators from the current operator mask on the current FM channel
;;; ------
;;; [bc modified]
fm_stop_op_from_mask::
        ;; stop the current OP
        ;; bc: address OPs running
        ld      a, (state_fm_channel_pipeline)
        add     a, #OPS_ENABLED
        ld      c, a
        ld      a, (state_fm_channel_pipeline+1)
        ld      b, a
        push    bc              ; +@ops_enabled
        ;; b: OPs running
        ld      a, (bc)
        ld      b, a
        ;; a: OPs to keep running
        ld      a, (state_fm_ym2610_op_mask)
        xor     #0xff
        and     #0xf0
        and     b
        pop     bc              ; -@ops_enabled
        ld      (bc), a
        ;; b: OPs to keep running
        ld      b, a
        ;; c: final on/off command for FM channel
        ld      a, (state_fm_ym2610_channel)
        add     b
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a
        ret


;;; Compute fixed-point note position after FX-pipeline
;;; ------
;;; IN:
;;;     ix: state for the current channel
;;; OUT:
;;;     hl: 16bits fixed-point note
compute_fm_fixed_point_note::
        ;; hl: current decimal note
        ld      l, NOTE16(ix)
        ld      h, NOTE16+1(ix)

        ;; + detuned semitone
        ld      c, DETUNE(ix)
        ld      b, DETUNE+1(ix)
        add     hl, bc

        ;; + arpeggio offset
        ld      c, #0
        ld      b, ARPEGGIO_POS8(ix)
        add     hl, bc

        ;; + vibrato offset if the vibrato FX is enabled
        bit     BIT_FX_VIBRATO, NOTE_FX(ix)
        jr      z, _fm_post_add_vibrato
        ld      c, NOTE_CTX+VIBRATO_POS16(ix)
        ld      b, NOTE_CTX+VIBRATO_POS16+1(ix)
        add     hl, bc
_fm_post_add_vibrato::

        ret


;;; Compute the YM2610's volume registers value from the OP's volumes
;;; ------
;;; modified: bc, de, hl
compute_ym2610_fm_vol::
        push    iy

        ;; a: note vol for current channel
        ld      a, VOL16+1(ix)

        ;; b: convert volume to attenuation
        neg
        add     #FM_MAX_VOL
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
        ld      de, #OUT_OP1
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
        ld      a, #FM_MAX_VOL
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
        ld      a, #FM_MAX_VOL
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


;;; run_fm_channel_pipeline
;;; ------
;;; Run the entire FM pipeline for a channel
;;;  - update the state of all enabled FX
;;;  - load specific parts of the state (note, vol...) into YM2610 registers
;;; Meant to run once per tick
run_fm_channel_pipeline::
        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        or      a, NOTE_FX(ix)
        cp      #0
        jp      z, _end_fm_channel_pipeline

        ;; Pipeline action: evaluate one FX step for each enabled FX

        ;; misc FX
        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _fm_channel_post_fx_trigger
        ld      hl, #state_fm_action_funcs
        call    eval_trigger_step
_fm_channel_post_fx_trigger:

        ;; iy: volume FX state for channel
        push    ix
        pop     iy
        ld      bc, #VOL_CTX
        add     iy, bc

        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _fm_channel_post_fx_vol_slide
        call    eval_slide_step
        set     BIT_LOAD_VOL, PIPELINE(ix)
_fm_channel_post_fx_vol_slide:

        ;; iy: note FX state for channel
        push    ix
        pop     iy
        ld      bc, #NOTE_CTX
        add     iy, bc

        bit     BIT_FX_SLIDE, NOTE_FX(ix)
        jr      z, _fm_channel_post_fx_slide
        call    eval_slide_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_channel_post_fx_slide:
        bit     BIT_FX_VIBRATO, NOTE_FX(ix)
        jr      z, _fm_channel_post_fx_vibrato
        call    eval_vibrato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_channel_post_fx_vibrato:
        bit     BIT_FX_ARPEGGIO, NOTE_FX(ix)
        jr      z, _fm_channel_post_fx_arpeggio
        call    eval_arpeggio_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_channel_post_fx_arpeggio:
        bit     BIT_FX_QUICK_LEGATO, NOTE_FX(ix)
        jr      z, _fm_channel_post_fx_legato
        call    eval_legato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_channel_post_fx_legato:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _fm_channel_post_check_playing
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_fm_channel_post_check_playing:

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
_fm_vol_load_loop:
        ld      c, (hl)
        call    ym2610_write_func
        dec     d
        jr      z, _post_load_fm_vol
        inc     hl
        ld      a, b
        add     a, #NSS_FM_NEXT_REGISTER
        ld      b, a
        jr      _fm_vol_load_loop
_post_load_fm_vol:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      z, _post_load_fm_note
        res     BIT_LOAD_NOTE, PIPELINE(ix)

        call    compute_fm_fixed_point_note
        ld      NOTE_POS16(ix), l
        ld      NOTE_POS16+1(ix), h
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
        ret



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

        ;; update pipeline for FM1 channel
        ld      a, #0
        call    fm_ctx_set_current
        call    run_fm_channel_pipeline

        ;; update pipeline for extended FM2 channel
        ld      a, #1
        call    fm_ctx_set_current
        ;; extended FM2? run pipeline for every independent OP
        ld      a, (state_timer_base_flags)
        bit     REG_TIMER_FLAGS_2CH_BIT, a
        jr      nz, _fm2_2ch_pipeline
        ;; otherwise run pipeline for FM2 channel
        call    run_fm_channel_pipeline
        jr      _post_fm2_pipeline
_fm2_2ch_pipeline:
        push    ix
        ld      a, #OP1_OFFSET
        call    fm_ctx_op_set_current
        call    run_op_pipeline
        ld      a, #OP2_OFFSET
        call    fm_ctx_op_set_current
        call    run_op_pipeline
        ld      a, #OP3_OFFSET
        call    fm_ctx_op_set_current
        call    run_op_pipeline
        ld      a, #OP4_OFFSET
        call    fm_ctx_op_set_current
        call    run_op_pipeline
        pop    ix
        ;; finish loading FM2 state into the YM2610
        call    run_fm2_pipeline
_post_fm2_pipeline:

        ;; update pipeline for FM3 channel
        ld      a, #2
        call    fm_ctx_set_current
        call    run_fm_channel_pipeline

        ;; update pipeline for FM4 channel
        ld      a, #3
        call    fm_ctx_set_current
        call    run_fm_channel_pipeline

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
;;; [ hl ]: volume [0-0x7f]
fm_vol::
        ;; a: volume
        ld      a, (hl)
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

        ;; b: fm channel
        ld      a, (state_fm_channel)
        ld      b, a

        ;; a: start register in YM2610 for FM channel
        ld      a, #REG_FM1_OP1_DETUNE_MULTIPLY
        res     1, b
        add     b

        ;; d: first props: DT | MUL
        ld      d, #NSS_FM_OPS_PROPS
        call    _fm_port_loop
        ;; skip TL props, they will be set up later
        add     a, #NSS_FM_NEXT_REGISTER_GAP
        ld      bc, #4          ; TODO remove that from instrument data
        add     hl, bc
        ;; set up the contiguous props
        ld      d, #NSS_FM_KS_AR_TO_SSG_PROPS
        call    _fm_port_loop
        ;; adjust for the last two props in the YM2610
        add     a, #NSS_FM_NEXT_REGISTER_GAP
        ld      d, #2
        call    _fm_port_loop

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

;;; Load data into consecutive YM2610 registers
;;; ------
;;;    a  : start FM register
;;;    d  : number of FM registers to load data into
;;; [ hl ]: YM2610 register data
;;; modified: bc, d, hl
_fm_port_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_func
        add     a, #NSS_FM_NEXT_REGISTER
        inc     hl
        dec     d
        jp      nz, _fm_port_loop
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


;;; Configure state for new note and trigger a load in the pipeline
;;; ------
fm_configure_note_on:
        push    bc
        ;; if a slide is ongoing, this is treated as a slide FX update
        bit     BIT_FX_SLIDE, NOTE_FX(ix)
        jr      z, _fm_cfg_note_update
        ld      bc, #NOTE_CTX
        call    slide_update
        ;; if a note is currently playing, do nothing else, the
        ;; portamento will be updated at the next pipeline run...
        bit     BIT_NOTE_STARTED, PIPELINE(ix)
        jr      nz, _fm_cfg_note_end
        ;; ... else prepare the note for reload as well
        jr      _fm_cfg_note_prepare_ym2610
_fm_cfg_note_update:
        ;; update the current note and prepare the ym2610
        ld      NOTE(ix), a
        ld      NOTE16+1(ix), a
        ld      NOTE16(ix), #0
        ;; legato have a special treatment below, otherwise prepare
        ;; state for playing a new note from the start
        bit     BIT_FX_LEGATO, NOTE_FX(ix)
        jr      z, _fm_post_cfg_note_update
        ;; legato is like regular note start when no note is playing...
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      z, _fm_cfg_start_new_note
        ;; ... otherwise it just consist in reloading a note frequency
        set     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      _fm_cfg_note_end
_fm_post_cfg_note_update:
        res     BIT_NOTE_STARTED, PIPELINE(ix)
_fm_cfg_note_prepare_ym2610:
        ;; stop playback on the current channel, and let the pipeline
        ;; restart the FM note from start, including the start of macro state
        call    fm_stop_op_from_mask
_fm_cfg_start_new_note:
        ld      a, PIPELINE(ix)
        or      #(STATE_PLAYING|STATE_EVAL_MACRO|STATE_LOAD_NOTE)
        ld      PIPELINE(ix), a
_fm_cfg_note_end:
        pop     bc

        ret


;;; Configure state for new volume and trigger a load in the pipeline
;;; ------
fm_configure_vol:
        ;; if a volume slide is ongoing, treat it as a volume slide FX update
        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _fm_cfg_vol_update
        push    bc
        ld      bc, #VOL_CTX
        call    slide_update
        pop     bc
        jr      _fm_cfg_vol_end
_fm_cfg_vol_update:
        ld      VOL(ix), a
        ld      VOL16+1(ix), a
        ld      VOL16(ix), #0
        ;; reload configured vol at the next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)
_fm_cfg_vol_end:
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
        ld      a, #1
        ret


;;; FM_NOTE_ON_AND_NEXT_CTX
;;; Emit a specific note (frequency) on an FM channel and
;;; immediately switch to the next FM context
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm_note_on_and_next_ctx::
        ;; process a regular note opcode
        call    fm_note_on

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
;;; IN:
;;;    a: OP enable mask
;;;   ix: FM pipeline
fm_stop_playback:
        push    bc

        ;; state: stop requested OPs (based on enable mask)
        ld      c, OPS_ENABLED(ix)
        and     c
        ld      OPS_ENABLED(ix), a
        ld      c, a

        ;; update playback state in the YM2610 for the channel
        ;; least significant nibble: FM channel
        ld      a, (state_fm_ym2610_channel)
        ;; most significant nibble: OPs that stay enabled
        or      c
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
;;; TODO implement delayed stop
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
fm_note_off::
        ld      a, #0x0f
        call    fm_stop_playback

        ld      a, #1
        ret


;;; FM_NOTE_OFF_AND_NEXT_CTX
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; Immediately switch to the next FM context.
;;; ------
fm_note_off_and_next_ctx::
        call    fm_note_off

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

;;; FM2_OP1_VOL
;;; Set the volume of OP1 for the FM2 channel when used in extended mode
;;; ------
;;; [ hl ]: volume level
fm2_op1_vol::
        push    ix
        ld      ix, #state_op1_pipeline
        call    fm_vol
        pop     ix
        ret

;;; FM2_OP2_VOL
;;; Set the volume of OP2 for the FM2 channel when used in extended mode
;;; ------
;;; [ hl ]: volume level
fm2_op2_vol::
        push    ix
        ld      ix, #state_op2_pipeline
        call    fm_vol
        pop     ix
        ret

;;; FM2_OP3_VOL
;;; Set the volume of OP3 for the FM2 channel when used in extended mode
;;; ------
;;; [ hl ]: volume level
fm2_op3_vol::
        push    ix
        ld      ix, #state_op3_pipeline
        call    fm_vol
        pop     ix
        ret

;;; FM2_OP4_VOL
;;; Set the volume of OP4 for the FM2 channel when used in extended mode
;;; ------
;;; [ hl ]: volume level
fm2_op4_vol::
        push    ix
        ld      ix, #state_op4_pipeline
        call    fm_vol
        pop     ix
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




;;;
;;; Helper functions for extended FM2 channels
;;;

;;; FM2_INSTRUMENT
;;; Configure an OP of FM2 channel based on an instrument's data
;;; ------
;;; IN:
;;;     a: OPx in YM2610 offset
;;;    ix: FM pipeline
;;;    iy: OP pipeline
;;;
;;; [ hl ]: OP
;;; [hl+1]: instrument number
fm2_instrument::
        push    bc
        push    de

        ;; set up OP context
        ld      (state_fm_ym2610_op), a
        ld      de, #_fm_ctx_op_mask_data
        add     e
        ld      e, a
        xor     a
        adc     d
        ld      d, a
        ld      a, (de)
        ld      (state_fm_ym2610_op_mask), a

        ;; ;; if the current instrument for channel is not updated, bail out
        ;; TODO move instrument to the OP structure to implement that
        ;; ld      b, INSTRUMENT(ix)
        ;; cp      b
        ;; jp      z, _fm_instr_end

        ;; a: instrument
        ld      a, (hl)
        inc     hl
        push    hl

        ;; ;; else recall new instrument for channel
        ;; TODO move instrument to the OP structure to implement that
        ;; ld      INSTRUMENT(ix), a

        ;; stop current FM channel (disable all OPs)
        push    af
        call    fm_stop_op_from_mask

        ;; TODO remove?
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

        ;; feedback/algo for channel
        ;; hl: instrument's channel props
        ld      de, #NSS_FM_INSTRUMENT_PROPS
        add     hl, de
        ld      b, #REG_FM2_FEEDBACK_ALGORITHM
        ;; NOTE: for some reasons, Furnace currently always
        ;; sets Feedback to the previously set value on FM2
        ;; when using an instrument on an extended OP track.
        ;; To be investigated further
        ;; TODO: OP1 sets its feedback from the instrument
        ld      a, (hl)
        and     #0x07
        ld      c, a
        ld      a, (state_fm_fm2_fb)
        or      c
        ld      c, a
        call    ym2610_write_func

        ;; ams/pms + current pan setting for FM2
        ld      a, #REG_FM2_L_R_AMSENSE_PMSENSE
        inc     hl
        call    fm_set_pan_ams_pms

        ;; reconfigure channel's output OP from algo
        ld      a, c
        and     #0x7
        ld      e, a
        ld      hl, #fm_out_ops_table
        add     hl, de
        ld      a, (hl)
        ld      OUT_OPS(ix), a

        ;; hl: operator settings for selected OP
        pop     hl              ; -instrument address
        ld      a, (state_fm_ym2610_op)
        ld      e, a
        ld      d, #0
        add     hl, de
        push    hl              ; +OP DT|MUL

        ;; a: start register in YM2610 for FM channel and OP
        ld      a, (state_fm_ym2610_op)
        sla     a
        sla     a
        add     #REG_FM2_OP1_DETUNE_MULTIPLY

        ;; load all instruments props for OP
        ld      de, #4
_fm2_port_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_func
        add     hl, de
        add     a, #NSS_OP_NEXT_REGISTER
        cp      #0xa0
        jr      c, _fm2_port_loop

        ;; set OP volume from instrument and configure a load
        ;; hl: TL for OP
        pop     hl              ; -OP DT|MUL
        ld      e, #4
        add     hl, de
        ;; b: instrument volume for OP
        ld      b, (hl)

        ;; hl: address of OP volume from FM pipeline
        push    ix
        pop     hl
        ld      de, #OP1
        add     hl, de
        ;; de: offset for OP [0..3]
        ld      a, (state_fm_ym2610_op)
        ld      e, a
        add     hl, de
        ld      (hl), b

        ;; setting a new instrument always trigger a note start,
        ;; register it for the next OP pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)
        res     BIT_NOTE_STARTED, PIPELINE(ix)
        set     BIT_LOAD_NOTE, PIPELINE(ix)

_fm2_instr_end:
        pop     hl
        pop     de
        pop     bc
        ld      a, #1
        ret


;;; Compute the YM2610's volume registers value from the OP's volumes
;;; ------
;;; IN:
;;;    ix: OP pipeline
;;;    iy: FM pipeline
;;; modified: bc, de, hl
compute_ym2610_op_vol::
        ;; hl: address of instrument's op volume
        push    iy
        pop     hl
        ld      de, #OP1
        ld      a, (state_fm_ym2610_op)
        add     e
        ld      e, a
        add     hl, de

        ;; a: note vol for current channel
        ld      a, VOL16+1(ix)

        ;; b: convert volume to attenuation
        neg
        add     #FM_MAX_VOL
        ld      b, a

        ;; a: OP level
        ld      a, (hl)

        ;; subtract intermediate volume (add attenuation)
        add     b
        bit     7, a
        jr      z, _c_op_post_clamp
        ld      a, #FM_MAX_VOL
_c_op_post_clamp:

        ;; substract global volume attenuation
        ;; NOTE: YM2610's FM output level ramp follows an exponential curve,
        ;; so we implement this output level attenuation via a basic
        ;; addition, clamped to 127 (max attenuation).
        ld      c, a
        ld      a, (state_fm_volume_attenuation)
        add     c
        bit     7, a
        jr      z, _c_op_post_global_clamp
        ld      a, #FM_MAX_VOL
_c_op_post_global_clamp:
        ld      c, a

        ;; hl: address of computed output volume
        ld      e, #OP_TO_OUT_OP
        add     hl, de

        ;; save computed OP volume value
        ld      (hl), a

        ret


;;; set OP context before calling an opcode handler
;;; IN:
;;;   bc: handler function
;;;   [ sp ]: bc
;;;   [sp+2]: ix
;;; OUT:
;;;   stack popped
;;;   ix, bc restored
;;;   result in a
;;; ------
;;; [ hl ]: OPx
;;; [hl+1]: vibrato params
fm2_op_ctx_and_action:
        ;; prepare call to handler
        ld      ix, #_post_op_handler
        push    ix
        push    bc

        ;; ix: OP pipeline
        ld      a, (hl)
        inc     hl
        ld      b, #0
        ld      c, a
        ld      ix, #_fm_ctx_op_pipeline_data
        add     ix, bc
        ld      b, (ix)
        ld      c, 4(ix)
        push    bc
        pop     ix

        ;; call handler
        ret
_post_op_handler:
        pop     bc
        pop     ix
        ret


;;; run_op_channel_pipeline
;;; ------
;;; Run the entire FM pipeline for an FM2 channel operator
;;;  - update the state of all enabled FX
;;;  - prepare YM2610 state update (note, vol...)
;;; Meant to run once per tick
;;; IN:
;;;   ix: OP pipeline
;;;   iy: FM pipeline
;;; OUT:
;;;   ix: FM pipeline (important!)
;;;
run_op_pipeline::
        ;; bail out if the current channel is not in use
        ld      a, PIPELINE(ix)
        or      a, FX(ix)
        or      a, NOTE_FX(ix)
        cp      #0
        jp      z, _end_op_pipeline

        push    iy              ; +fm ctx

        ;; misc FX
        bit     BIT_FX_TRIGGER, FX(ix)
        jr      z, _op_post_op_trigger
        ld      hl, #state_fm_action_funcs
        call    eval_trigger_step
_op_post_op_trigger:

        ;; iy: volume FX state for channel
        push    ix
        pop     iy
        ld      bc, #VOL_CTX
        add     iy, bc

        bit     BIT_FX_SLIDE, FX(ix)
        jr      z, _op_post_op_vol_slide
        call    eval_slide_step
        set     BIT_LOAD_VOL, PIPELINE(ix)
_op_post_op_vol_slide:

        ;; iy: note FX state for channel
        push    ix
        pop     iy
        ld      bc, #NOTE_CTX
        add     iy, bc

        bit     BIT_FX_SLIDE, NOTE_FX(ix)
        jr      z, _op_post_op_slide
        call    eval_slide_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_op_post_op_slide:
        bit     BIT_FX_VIBRATO, NOTE_FX(ix)
        jr      z, _op_post_op_vibrato
        call    eval_vibrato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_op_post_op_vibrato:
        bit     BIT_FX_ARPEGGIO, NOTE_FX(ix)
        jr      z, _op_post_op_arpeggio
        call    eval_arpeggio_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_op_post_op_arpeggio:
        bit     BIT_FX_QUICK_LEGATO, NOTE_FX(ix)
        jr      z, _op_post_op_legato
        call    eval_legato_step
        set     BIT_LOAD_NOTE, PIPELINE(ix)
_op_post_op_legato:

        ;; Pipeline action: make sure no load note takes place when not playing
        bit     BIT_PLAYING, PIPELINE(ix)
        jr      nz, _op_post_check_playing
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_op_post_check_playing:

        ;; Pipeline action: load volume registers when the volume state is modified
        bit     BIT_LOAD_VOL, PIPELINE(ix)
        jr      z, _post_load_op_vol
        res     BIT_LOAD_VOL, PIPELINE(ix)

        ;; iy: pipeline for current FM channel
        pop     iy
        push    iy
        call    compute_ym2610_op_vol

        ;; hl: address of instrument's op volume
        push    iy
        pop     hl
        ;; de: offset from FM2 pipeline to OUT_OPx
        ld      de, #OUT_OP1
        ld      a, (state_fm_ym2610_op)
        add     e
        ld      e, a
        add     hl, de

        ;; load OP volume
        ld      a, (state_fm_op_tl_reg)
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_func
_post_load_op_vol:

        ;; Pipeline action: load note register when the note state is modified
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      nz, _load_op_note
        pop     iy              ; -fm ctx
        jr      _post_load_op_note
_load_op_note:
        res     BIT_LOAD_NOTE, PIPELINE(ix)

        ;; recall this OP has started note playback
        set     BIT_NOTE_STARTED, PIPELINE(ix)

        ;; lh: final fixed-point note after all FX
        ;; NOTE: this stores the value into a single location, so
        ;; ext-FM2 does not keep track of computed data for all OPs
        call    compute_fm_fixed_point_note
        pop     ix              ; -fm ctx
        ld      NOTE_POS16(ix), l
        ld      NOTE_POS16+1(ix), h
        ;; compute the block*F-num equivalent from fixed-point note
        call    compute_ym2610_fm_note

        ;; reload computed note
        ld      l, NOTE_FNUM(ix)
        ld      h, NOTE_FNUM+1(ix)
        ld      c, NOTE_BLOCK(ix)
        call    fm_set_fnum_registers

        ;; configure the FM2 channel to load this OP node
        ld      a, (state_fm_ym2610_op_mask)
        ld      b, OPS_ENABLED(ix)
        or      b
        ld      OPS_ENABLED(ix), a
        set     BIT_LOAD_NOTE, PIPELINE(ix)

_post_load_op_note:
_end_op_pipeline:
        ret


;;; run_fm2_pipeline
;;; ------
;;; Finish loading parts of the FM2 state (note, vol...) into YM2610 registers
;;; NOTE: for extended FM2, each OP pipeline holds its own load bits. All the
;;; load bits are consolidated into another FM pipeline state, which is used
;;; to group loads to the YM2610 after each OP pipeline has run.
;;; ix: FM pipeline
;;;
run_fm2_pipeline::
        bit     BIT_LOAD_NOTE, PIPELINE(ix)
        jr      z, _post_load_fm2_note
        ld      a, OPS_ENABLED(ix)
        or      #2
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a
        res     BIT_LOAD_NOTE, PIPELINE(ix)
_post_load_fm2_note:

        ret




;;;
;;; NSS opcodes applied on extended FM2 channels
;;;

;;; FM2_OPx_INSTR
;;; Configure an OP of FM2 channel based on an instrument's data
;;; ------
;;; IN:
;;;    ix: FM2 pipeline
;;; [ hl ]: detune
fm2_op1_instr::
        push    iy
        ld      iy, #state_op1_pipeline
        ld      a, #OP1_OFFSET
        call    fm2_instrument
        pop     iy
        ld      a, #1
        ret

fm2_op2_instr::
        push    iy
        ld      iy, #state_op2_pipeline
        ld      a, #OP2_OFFSET
        call    fm2_instrument
        pop     iy
        ld      a, #1
        ret

fm2_op3_instr::
        push    iy
        ld      iy, #state_op3_pipeline
        ld      a, #OP3_OFFSET
        call    fm2_instrument
        pop     iy
        ld      a, #1
        ret

fm2_op4_instr::
        push    iy
        ld      iy, #state_op4_pipeline
        ld      a, #OP4_OFFSET
        call    fm2_instrument
        pop     iy
        ld      a, #1
        ret


;;; FM2_OP1_NOTE_ON
;;; Emit a specific note (frequency) on the OP1 FM2 channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm2_op1_note_on::
        ld      a, #0x10
        ld      (state_fm_ym2610_op_mask), a
        push    ix
        ld      ix, #state_op1_pipeline
        call    fm_note_on
        pop     ix
        ret


;;; FM2_OP2_NOTE_ON
;;; Emit a specific note (frequency) on the OP2 FM2 channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm2_op2_note_on::
        ld      a, #0x20
        ld      (state_fm_ym2610_op_mask), a
        push    ix
        ld      ix, #state_op2_pipeline
        call    fm_note_on
        pop     ix
        ret


;;; FM2_OP3_NOTE_ON
;;; Emit a specific note (frequency) on the OP3 FM2 channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm2_op3_note_on::
        ld      a, #0x40
        ld      (state_fm_ym2610_op_mask), a
        push    ix
        ld      ix, #state_op3_pipeline
        call    fm_note_on
        pop     ix
        ret


;;; FM2_OP4_NOTE_ON
;;; Emit a specific note (frequency) on the OP4 FM2 channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm2_op4_note_on::
        ld      a, #0x80
        ld      (state_fm_ym2610_op_mask), a
        push    ix
        ld      ix, #state_op4_pipeline
        call    fm_note_on
        pop     ix
        ret


;;; FM_OPS_OFF
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
;;; [ hl ]: o4|o3|o2|o1|.1|.1|.1|.1, 0 means off
fm2_ops_off::
        ld      a, (hl)
        xor     #0xff
        push    ix
        ld      ix, #state_op4_pipeline
        call    _ops_check_off
        ld      ix, #state_op3_pipeline
        call    _ops_check_off
        ld      ix, #state_op2_pipeline
        call    _ops_check_off
        ld      ix, #state_op1_pipeline
        call    _ops_check_off
        pop     ix

        ld      a, (hl)
        inc     hl
        call    fm_stop_playback

        ld      a, #1
        ret
_ops_check_off:
        rla
        jp      nc, _ops_check_off_ret
        ;; disable playback in the pipeline, any load_note bit
        ;; will get cleaned during the next pipeline run
        res     BIT_PLAYING, PIPELINE(ix)
_ops_check_off_ret:
        ret


;;; FM2_DELAY
;;; ------
;;; [ hl ]: OP
;;; [hl+1]: delay params
fm2_delay::
        push    ix
        push    bc
        ld      bc, #fm_delay
        jp      fm2_op_ctx_and_action


;;; FM2_VIBRATO
;;; ------
;;; [ hl ]: OPx
;;; [hl+1]: vibrato params
fm2_vibrato:
        push    ix
        push    bc
        ld      bc, #vibrato
        jp      fm2_op_ctx_and_action


;;; FM2_VIBRATO_OFF
;;; ------
;;; [ hl ]: OPx
fm2_vibrato_off:
        push    ix
        push    bc
        ld      bc, #vibrato_off
        jp      fm2_op_ctx_and_action


;;; NOTE_PORTAMENTO
;;; ------
;;; [ hl ]: OPx
;;; [hl+1]: portamento params
fm2_note_portamento::
        push    ix
        push    bc
        ld      bc, #note_portamento
        jp      fm2_op_ctx_and_action


;;; FM2_LEGATO
;;; ------
;;; [ hl ]: OPx
fm2_legato:
        push    ix
        push    bc
        ld      bc, #legato
        jp      fm2_op_ctx_and_action


;;; FM2_LEGATO_OFF
;;; ------
;;; [ hl ]: OPx
fm2_legato_off:
        push    ix
        push    bc
        ld      bc, #legato_off
        jp      fm2_op_ctx_and_action


;;; FM2_VOL_SLIDE_OFF
;;; ------
;;; [ hl ]: OPx
fm2_vol_slide_off:
        push    ix
        push    bc
        ld      bc, #vol_slide_off
        jp      fm2_op_ctx_and_action


;;; FM2_VOL_SLIDE_UP
;;; ------
;;; [ hl ]: OPx
;;; [hl+1]: slide params
fm2_vol_slide_up::
        push    ix
        push    bc
        ld      bc, #vol_slide_up
        jp      fm2_op_ctx_and_action


;;; FM2_VOL_SLIDE_DOWN
;;; ------
;;; [ hl ]: OPx
;;; [hl+1]: slide params
fm2_vol_slide_down::
        push    ix
        push    bc
        ld      bc, #vol_slide_down
        jp      fm2_op_ctx_and_action
