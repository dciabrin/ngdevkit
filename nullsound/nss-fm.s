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


        .equ    NSS_FM_INSTRUMENT_PROPS,        28
        .equ    NSS_FM_NEXT_REGISTER,           4
        .equ    NSS_FM_NEXT_REGISTER_GAP,       16
        .equ    NSS_FM_END_OF_REGISTERS,        0xb7
        .equ    INSTR_TL_OFFSET,                4
        .equ    INSTR_FB_ALGO_OFFSET,           28
        .equ    INSTR_ALGO_MASK,                7

        .equ    FM_STATE_SIZE,(state_fm_end-state_fm)
        .equ    FM_FX,(state_fm_fx-state_fm)

        .equ    NOTE_SEMITONE,(state_fm_note_semitone-state_fm)
        .equ    NOTE_FNUM,(state_fm_note_fnum-state_fm)
        .equ    NOTE_BLOCK,(state_fm_note_block-state_fm)

        ;; this is to use IY as two IYH and IYL 8bits registers
        .macro dec_iyl
        .db     0xfd, 0x2d
        .endm

        .area  DATA

;;; FM playback state tracker
;;; ------

;;; write to the ym2610 port that matches the current context
ym2610_write_func:
        .blkb   3               ; space for `jp 0x....`

;;; context: current fm channel for opcode actions
_state_fm_start:
state_fm_channel::
        .db     0
state_fm_ym2610_channel::
        .db     0

;;; FM mirrored state
state_fm:
;;; FM1
state_fm_fx: .db     0             ; must be the first field on the FM state
;;; FX: slide
state_fm_slide:
state_fm_slide_speed: .db       0  ; number of increments per tick
state_fm_slide_depth: .db       0  ; distance in semitones
state_fm_slide_inc16: .dw       0  ; 1/8 semitone increment * speed
state_fm_slide_pos16: .dw       0  ; slide pos
state_fm_slide_end:   .db       0  ; end note (octave/semitone)
;;; FX: vibrato
state_fm_vibrato:
state_fm_vibrato_speed: .db     0  ; vibrato_speed
state_fm_vibrato_depth: .db     0  ; vibrato_depth
state_fm_vibrato_pos:   .db     0  ; vibrato_pos
state_fm_vibrato_prev:  .dw     0  ; vibrato_prev
state_fm_vibrato_next:  .dw     0  ; vibrato_next
;;; Note
state_fm_note:
state_fm_note_semitone: .db    0  ; note (octave+semitone)
state_fm_note_fnum:     .dw    0  ; note base f-num
state_fm_note_block:    .db    0  ; note block (multiplier)
state_fm_end:
;;; FM2
.blkb   FM_STATE_SIZE
;;; FM3
.blkb   FM_STATE_SIZE
;;; FM4
.blkb   FM_STATE_SIZE


;;; detune per FM channel
state_fm_detune::
        .db     0
        .db     0
        .db     0
        .db     0

;;; current note volume per FM channel
state_fm_vol::
        .db     0
        .db     0
        .db     0
        .db     0

;;; bitfields for the output OPs based on the channel's configured algorithm
state_fm_out_ops::
        .db     0
        .db     0
        .db     0
        .db     0

_state_fm_end:


        .area  CODE


;;;  Reset FM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_fm_state_tracker::
        ld      hl, #_state_fm_start
        ld      d, h
        ld      e, l
        inc     de
        ld      (hl), #0
        ld      bc, #_state_fm_end-_state_fm_start
        ldir
        ;; init ym2610 function pointer
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


;;; FM_INSTRUMENT_EXT
;;; Configure the operators of an FM channel based on an instrument's data
;;; ------
;;; [ hl ]: FM channel
;;; [hl+1]: instrument number
fm_instrument_ext::
        ;; set new current FM channel
        ld      a, (hl)
        call    fm_ctx_set_current
        inc     hl
        jp      fm_instrument


;;; output OPs based on the layout of each FM algorithm of the YM2610
;;;  7   6   5   4   3   2   1   0
;;; ___ ___ ___ ___ OP4 OP3 OP2 OP1
fm_out_ops_table:
        .db     0x8             ; algo 0: OP4
        .db     0x8             ; algo 1: OP4
        .db     0x8             ; algo 2: OP4
        .db     0x8             ; algo 3: OP4
        .db     0xa             ; algo 4: OP2, OP4
        .db     0xe             ; algo 5: OP2, OP3, OP4
        .db     0xe             ; algo 6: OP2, OP3, OP4
        .db     0xf             ; algo 7: OP1, OP2, OP3, OP4


;;; fm_set_out_ops_bitfield
;;; Configure the output OPs on an instrument's data
;;; ------
;;; hl: instrument address
fm_set_out_ops_bitfield::
        push    hl

        ;; de: OPs out address for channel
        ld      hl, #state_fm_out_ops
        ld      a, (state_fm_channel)
        ld      c, a
        ld      b, #0
        add     hl, bc
        ld      d, h
        ld      e, l

        ;; hl: address of instrument data's algo
        pop     hl
        ld      bc, #INSTR_FB_ALGO_OFFSET
        add     hl, bc

        ;; a: algo
        ld      a, (hl)
        and     #INSTR_ALGO_MASK

        ;; hl: bitfield address for algo
        ld      hl, #fm_out_ops_table
        ld      c, a
        ld      b, #0
        add     hl, bc

        ;; set OPs out info for current channel
        ld      a, (hl)
        ld      (de), a

        ret


;;; fm_set_ops_level
;;; Configure the operators of an FM channel based on an instrument's data
;;; ------
;;; hl: instrument address
fm_set_ops_level::
        push    hl

        ;; bc: current channel
        ld      a, (state_fm_channel)
        ld      c, a
        ld      b, #0

        ;; d: note volumes for current channel
        ld      hl, #state_fm_vol
        add     hl, bc
        ld      d, (hl)

        ;; e: bitfields for the output OPs
        ld      hl, #state_fm_out_ops
        add     hl, bc
        ld      e, (hl)

        ;; b: OP1 start register in YM2610 for current channel
        res     1, a
        add     a, #REG_FM1_OP1_TOTAL_LEVEL
        ld      b, a

        ;; hl: ops total level (8bit add)
        pop     hl              ; instrument address
        ld      a, #INSTR_TL_OFFSET
        add     a, l
        ld      l, a

_ops_loop:
        ;; check whether current OP is an output
        bit     0, e
        jr      z, _ops_next_op
        ;; current OP's total level per instrument
        ld      a, (hl)
        ;; mix with note volume and clamp
        add     d
        bit     7, a
        jr      z, _ops_post_clamp
        ld      a, #127
_ops_post_clamp:
        and     #0x7f
        ld      c, a
        call    ym2610_write_func
_ops_next_op:
        ;; next OP in instrument data
        inc     hl
        ;; next OP in YM2610
        ld      a, b
        add     a, #NSS_FM_NEXT_REGISTER
        ld      b, a
        ;; shirt right to get next OP in bitfield (keep e6 bit clean)
        sra     e
        res     6, e
        ld      a, e
        and     #0xf
        jr      nz, _ops_loop
_ops_end_loop:
        ret


;;; update_fm_effects
;;; ------
;;; For all FM channels:
;;;  - update the state of all enabled effects
;;; Meant to run once per tick
update_fm_effects::
        push    de
        ;; TODO should we consider IX and IY scratch registers?
        push    iy
        push    ix

        ;; effects expect the right FM channel context,
        ;; so save the current channel context and loop
        ;; it artificially before calling the macro
        ld      a, (state_fm_channel)
        push    af

        ;; update mirrored state of all FM channels

        ld      de, #state_fm ; FM1 mirrored state
        xor     a
        call    fm_ctx_set_current ; fm ctx: fm1
        ld      iy, #4
_2_update_loop:
        push    de              ; +state_mirrored
        ;; hl: mirrored state
        push    de              ; state_mirrored
        pop     hl              ; state_mirrored

        ;; configure
        ld      a, (hl)
_fm_chk_fx_vibrato:
        bit     0, a
        jr      z, _fm_chk_fx_slide
        call    eval_fm_vibrato_step
        jr      _fm_post_effects
_fm_chk_fx_slide:
        bit     1, a
        jr      z, _fm_post_effects
        call    eval_fm_slide_step
_fm_post_effects:
        ;; prepare to update the next channel
        ;; de: next state_mirrored
        pop     hl              ; -state_mirrored
        ld      bc, #FM_STATE_SIZE
        add     hl, bc
        ld      d, h
        ld      e, l
        ;; next FM context
        ld      a, (state_fm_channel)
        inc     a
        call    fm_ctx_set_current

        dec_iyl
        jp      nz, _2_update_loop

        ;; restore the real fm channel context
        pop     af
        call    fm_ctx_set_current

        pop     ix
        pop     iy
        pop     de
        ret


;;; FM_VOL
;;; Set the note volume for the current FM channel
;;; Note: FM_INSTRUMENT must have run before this opcode
;;; ------
;;; [ hl ]: volume [0-127]
fm_vol::
        push    de

        ;; de: volume for channel (8bit add)
        ld      de, #state_fm_vol
        ld      a, (state_fm_channel)
        add     a, e
        ld      e, a

        ;; a: volume (difference from max volume)
        ld      a, #127
        sub     (hl)
        inc     hl

        ld      (de), a

        pop     de

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

        ;; b: fm channel
        ld      c, a
        ld      a, (state_fm_channel)
        ld      b, a
        ld      a, c

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

        ;; save instrument address for helper funcs
        push    hl
        push    hl

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
        ld      d, #2
        jp      _fm_port_loop

_fm_end:
        ;; set the output OPs for this instrument
        pop     hl
        call    fm_set_out_ops_bitfield
        ;; adjust real volume for channel based on instrument's
        ;; config and current note volume
        pop     hl
        call    fm_set_ops_level

        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; FM_PITCH
;;; Configure note detune for the current FM channel
;;; ------
;;; [ hl ]: detune
fm_pitch::
        push    bc
        ;; bc: address of detune for current FM channel
        ld      bc, #state_fm_detune
        ld      a, (state_fm_channel)
        add     a, c
        ld      c, a
        add     a, b
        sub     c
        ld      b, a

        ;; a: detune
        ld      a, (hl)
        inc     hl
        ld      (bc), a

        pop     bc
        ld      a, #1
        ret


;;; Semitone frequency table
;;; ------
;;; A note in nullsound is represented as a tuple <octave, semitone>,
;;; which is translated into YM2610's register representation
;;; `block * F-number`, where F-number is a factor of the semitone's
;;; frequency, and block is a power of 2 (handy for octaves)
fm_note_f_num:
        .db      0x02, 0x69  ;  617 - C
        .db      0x02, 0x8e  ;  654 - C#
        .db      0x02, 0xb5  ;  693 - D
        .db      0x02, 0xde  ;  734 - D#
        .db      0x03, 0x09  ;  777 - E
        .db      0x03, 0x38  ;  824 - F
        .db      0x03, 0x69  ;  873 - F#
        .db      0x03, 0x9d  ;  925 - G
        .db      0x03, 0xd4  ;  980 - G#
        .db      0x04, 0x0e  ; 1038 - A
        .db      0x04, 0x4c  ; 1100 - A#
        .db      0x04, 0x8d  ; 1165 - B
        .db      0x04, 0xd1  ; 1233 - C+1


;;; Vibrato - semitone distance table
;;; ------
;;; The distance between a semitone's f-num and the previous semitone's f-num.
;;; This is the same for all octaves.
;;; The vibrato effect oscillate between one semi-tone up and down of the
;;; current note of the FM channel.
fm_semitone_distance::
        ;;        C ,   C#,   D ,   D#,   E ,   F ,   F#,   G ,   G#,   A ,   A#,   B ,  C+1
        .db     0x25, 0x27, 0x29, 0x2b, 0x2f, 0x31, 0x34, 0x37, 0x3a, 0x3e, 0x41, 0x44, 0x4a


;;; Get the effective F-num from the current FM channel
;;; ------
;;; [ hl ]: F-Num position in the semitone frequency table
;;; OUT:
;;;   hl  : detuned F-num based on current detune context
fm_get_f_num:
        push    bc
        ld      a, (hl)
        inc     hl
        ld      b, a
        ld      a, (hl)
        ld      c, a
        ;; hl: 10bits f-num
        ld      h, b
        ld      l, c

        ;; bc: address of detune for current FM channel
        ld      bc, #state_fm_detune
        ld      a, (state_fm_channel)
        add     a, c
        ld      c, a
        add     a, b
        sub     c
        ld      b, a

        ;; a: detune
        ld      a, (bc)

        ;; hl += a (16bits + signed 8bits)
        cp      #0x80
        jr      c, _detune_positive
        dec     h
_detune_positive:
        ; Then do addition as usual
        ; (to handle the "lower byte")
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a

        pop     bc
        ret


;;; Configure the FM channel based on a macro's data
;;; ------
;;; IN:
;;;   de: start offset in FM state data
;;; OUT
;;;   de: start offset for the current channel
;;; de, c modified
fm_state_for_channel:
        ;; c: current channel
        ld      a, (state_fm_channel)
        ld      c, a
        ;; a: offset in bytes for current mirrored state
        xor     a
        bit     1, c
        jp      z, _fm_post_double
        ld      a, #FM_STATE_SIZE
        add     a
_fm_post_double:
        bit     0, c
        jp      z, _fm_post_plus
        add     #FM_STATE_SIZE
_fm_post_plus:
        ;; de + a (8bit add)
        add     a, e
        ld      e, a
        ret


;;; Update the vibrato for the current FM channel and update the YM2610
;;; ------
;;; hl: mirrored state of the current fm channel
eval_fm_vibrato_step::
        push    hl
        push    de
        push    bc
        push    ix

        ;; ix: state fx for current channel
        push    hl
        pop     ix

        call    vibrato_eval_step

        ;; ;; configure FM channel with new frequency
        ld      c, NOTE_BLOCK(ix)
        call    fm_set_fnum_registers

        pop     ix
        pop     bc
        pop     de
        pop     hl

        ret


;;; Setup FM vibrato: position and increments
;;; ------
;;; ix : ssg state for channel
;;;      the note semitone must be already configured
fm_vibrato_setup_increments::
        push    bc
        push    hl
        push    de

        ld      hl, #fm_semitone_distance
        ld      a, NOTE_SEMITONE(ix)
        and     #0xf
        add     l
        ld      l, a
        call    vibrato_setup_increments

        ;; de: vibrato prev increment, fixed point (negate)
        xor     a
        sub     e
        ld      e, a
        sbc     a, a
        sub     d
        ld      d, a
        ld      VIBRATO_PREV(ix), e
        ld      VIBRATO_PREV+1(ix), d
        ;; hl: vibrato next increment, fixed point
        ld      VIBRATO_NEXT(ix), l
        ld      VIBRATO_NEXT+1(ix), h

        pop     de
        pop     hl
        pop     bc
        ret


;;; Setup slide effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
;;;    a  : slide direction: 0 == up, 1 == down
fm_slide_common::
        push    bc
        push    de

        ;; de: FX for channel
        ld      b, a
        ld      de, #state_fm_fx
        call    fm_state_for_channel
        ld      a, b

        ;; ix: FM state for channel
        push    de
        pop     ix

        call    slide_init
        ld      e, NOTE_SEMITONE(ix)
        call    slide_setup_increments

        pop     de
        pop     bc

        ret


;;; Update the slide for the current channel
;;; Slide moves up or down by 1/8 of semitone increments * slide depth.
;;; ------
;;; hl: state for the current channel
eval_fm_slide_step::
        push    hl
        push    de
        push    bc
        push    ix

        ;; update internal state for the next slide step
        call    eval_slide_step

        ;; effect still in progress?
        cp      a, #0
        jp      nz, _fm_slide_add_intermediate
        ;; otherwise reset note state and load into YM2610
        ld      NOTE_SEMITONE(ix), d
        ;; a: semitone
        ld      a, d
        and     #0xf
        ;; hl: base f-num for current semitone (8bit-add)
        ld      hl, #fm_note_f_num
        sla     a
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a
        ;; restore detune at the end of the effect if there was any
        call    fm_get_f_num
        ld      NOTE_FNUM(ix), l
        ld      NOTE_FNUM+1(ix), h
        ld      a, d
        jr      _fm_slide_load_fnum

_fm_slide_add_intermediate:
        ;; a: current semitone
        ld      a, SLIDE_POS16+1(ix)
        and     #0xf
        ;; b: next semitone distance from current note
        ld      hl, #fm_semitone_distance
        add     l
        inc     a
        ld      l, a
        ld      b, (hl)
        ;; c: FM: intermediate frequency is positive
        ld      c, #0
        ;; e: intermediate semitone position (fractional part)
        ld      e, SLIDE_POS16(ix)
        ;; de: current intermediate frequency f_dist
        call    slide_intermediate_freq

        ;; a: semitone
        ld      a, SLIDE_POS16+1(ix)
        and     #0xf
        ;; hl: base f-num for current semitone (8bit-add)
        ld      hl, #fm_note_f_num
        sla     a
        add     a, l
        ld      l, a
        adc     a, h
        sub     l
        ld      h, a
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        ld      h, b
        ld      l, c

        ;; load new frequency into the YM2610
        ;; hl: semitone frequency + f_dist
        add     hl, de

        ;; a: block
        ld      a, SLIDE_POS16+1(ix)

_fm_slide_load_fnum:
        and     #0xf0
        sra     a
        ld      NOTE_BLOCK(ix), a
        ld      c, a
        call    fm_set_fnum_registers

        pop     ix
        pop     bc
        pop     de
        pop     hl

        ret


;;; FM_NOTE_ON_EXT
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: FM channel
;;; [hl+1]: note (0xAB: A=octave B=semitone)
fm_note_on_ext::
        ;; set new current FM channel
        ld      a, (hl)
        call    fm_ctx_set_current
        inc     hl
        jp      fm_note_on


;;; FM_NOTE_ON
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm_note_on::
        push    de
        push    bc

        ;; iy: note for channel
        ld      de, #state_fm
        call    fm_state_for_channel
        push    de
        pop     ix

        ;; stop current FM channel (disable all OPs)
        ld      a, (state_fm_ym2610_channel)
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        ;; record note, block and freq to FM state
        ;; b: note (0xAB: A=octave B=semitone)
        ld      b, (hl)
        inc     hl
        push    hl
        ld      NOTE_SEMITONE(ix), b

        ;; check active effects
        ld      a, (ix)
_fm_on_check_vibrato:
        bit     0, a
        jr      z, _fm_on_check_slide
        ;; reconfigure increments for current semitone
        call    fm_vibrato_setup_increments
_fm_on_check_slide:
        bit     1, a
        jr      z, _fm_on_post_fx
        ;; reconfigure increments for current semitone
        ld      e, NOTE_SEMITONE(ix)
        call    slide_setup_increments
_fm_on_post_fx:

        ;; d: block (octave)
        ld      a, b
        and     #0xf0
        sra     a
        ld      d, a
        ld      NOTE_BLOCK(ix), d

        ;; a: semitone
        ld      a, b
        and     #0xf
        ;; hl: semitone -> f_num address
        ld      hl, #fm_note_f_num
        sla     a
        ld      b, #0
        ld      c, a
        add     hl, bc
        ;; hl: fnum address -> (de)tuned F-num
        call    fm_get_f_num
        ld      NOTE_FNUM(ix), l
        ld      NOTE_FNUM+1(ix), h
        ;; c: block
        ld      c, d
        call    fm_set_fnum_registers

        ;; start current FM channel (enable all OPs)
        ld      a, (state_fm_ym2610_channel)
        or      #0xf0
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        pop     hl
        pop     bc
        pop     de

        ;; fm context will now target the next channel
        ld      a, (state_fm_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; FM_NOTE_OFF_EXT
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
;;; [ hl ]: FM channel
fm_note_off_ext::
        ;; set new current FM channel
        ld      a, (hl)
        call    fm_ctx_set_current
        inc     hl
        jp      fm_note_off


;;; FM_NOTE_OFF
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
fm_note_off::
        push    bc

        ;; stop all OP of FM channel
        ld      a, (state_fm_ym2610_channel)
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        pop     bc

        ;; FM context will now target the next channel
        ld      a, (state_fm_channel)
        inc     a
        call    fm_ctx_set_current

        ld      a, #1
        ret


;;; OPX_SET_COMMON
;;; Set an operator's property for the current FM channel
;;; ------
;;; [ b  ]: register of the OP's property
;;; [ c  ]: value

opx_set_common::
        push    bc
        push    de

        ;; e: fm channel
        ld      a, (state_fm_channel)
        ld      e, a

        ;; adjust register based on channel
        bit     0, e
        jp      z, _no_adj
        inc     b
_no_adj:
        call    ym2610_write_func

        pop     de
        pop     bc
        ret


;;; OP1_LVL
;;; Set the volume of OP1 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op1_lvl::
        push    bc
        ld      b, #REG_FM1_OP1_TOTAL_LEVEL
        ld      c, (hl)
        inc     hl
        call    opx_set_common
        pop     bc
        ld      a, #1
        ret


;;; OP2_LVL
;;; Set the volume of OP2 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op2_lvl::
        push    bc
        ld      b, #REG_FM1_OP2_TOTAL_LEVEL
        ld      c, (hl)
        inc     hl
        call    opx_set_common
        pop     bc
        ld      a, #1
        ret


;;; OP3_LVL
;;; Set the volume of OP3 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op3_lvl::
        push    bc
        ld      b, #REG_FM1_OP3_TOTAL_LEVEL
        ld      c, (hl)
        inc     hl
        call    opx_set_common
        pop     bc
        ld      a, #1
        ret


;;; OP4_LVL
;;; Set the volume of OP4 for the current FM channel
;;; ------
;;; [ hl ]: volume level
op4_lvl::
        push    bc
        ld      b, #REG_FM1_OP4_TOTAL_LEVEL
        ld      c, (hl)
        inc     hl
        call    opx_set_common
        pop     bc
        ld      a, #1
        ret


;;; FM_VIBRATO
;;; Enable vibrato for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_vibrato::
        push    bc
        push    de

        ;; de: fx for channel
        ld      de, #state_fm_fx
        call    fm_state_for_channel
        push    de
        pop     ix

        ;; hl == 0 means disable vibrato
        ld      a, (hl)
        cp      #0
        jr      nz, _setup_fm_vibrato
        push    hl              ; NSS stream pos

        ;; disable vibrato fx
        ld      a, FM_FX(ix)
        res     0, a
        ld      FM_FX(ix), a
        ;; reconfigure the original note into the YM2610
        ld      l, NOTE_FNUM(ix)
        ld      h, NOTE_FNUM+1(ix)
        ld      c, NOTE_BLOCK(ix)
        call    fm_set_fnum_registers

        pop     hl              ; NSS stream pos
        jr      _post_fm_vibrato_setup

_setup_fm_vibrato:
        ;; vibrato fx on
        ld      a, FM_FX(ix)
        ;; if vibrato was in use, keep the current vibrato pos
        bit     0, a
        jp      nz, _post_fm_vibrato_pos
        ;; reset vibrato sine pos
        ld      VIBRATO_POS(ix), #0
_post_fm_vibrato_pos:
        set     0, a
        ld      FM_FX(ix), a

        ;; speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      VIBRATO_SPEED(ix), a

        ;; depth, clamped to [1..16]
        ld      a, (hl)
        and     #0xf
        inc     a
        ld      VIBRATO_DEPTH(ix), a

        ;; increments for last configured note
        call    fm_vibrato_setup_increments

_post_fm_vibrato_setup:
        inc     hl

        pop     de
        pop     bc

        ld      a, #1
        ret


;;; FM_SLIDE_UP
;;; Enable slide up effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_slide_up::
        ld      a, #0
        call    fm_slide_common
        ld      a, #1
        ret


;;; FM_SLIDE_DOWN
;;; Enable slide down effect for the current FM channel
;;; ------
;;; [ hl ]: speed (4bits) and depth (4bits)
fm_slide_down::
        ld      a, #1
        call    fm_slide_common
        ld      a, #1
        ret
