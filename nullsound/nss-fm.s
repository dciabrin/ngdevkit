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

        .equ    NSS_FM_INSTRUMENT_PROPS,        28
        .equ    NSS_FM_NEXT_REGISTER,           4
        .equ    NSS_FM_NEXT_REGISTER_GAP,       16
        .equ    NSS_FM_END_OF_REGISTERS,        0xb7
        .equ    INSTR_TL_OFFSET,                4
        .equ    INSTR_FB_ALGO_OFFSET,           28
        .equ    INSTR_ALGO_MASK,                7



        .area  DATA

;;; FM playback state tracker
;;; ------

;;; context: current fm channel for opcode actions
_state_fm_start:
state_fm_channel::
        .db     0

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
        ret


;;;  Reset FM playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
fm_ctx_reset::
        ld      a, #0
        ld      (state_fm_channel), a
        ret


;;; FM NSS opcodes
;;; ------

;;; FM_CTX_1
;;; Set the current FM track to be FM1 for the next FM opcode processing
;;; ------
fm_ctx_1::
        ;; set new current FM channel
        ld      a, #0
        ld      (state_fm_channel), a
        ld      a, #1
        ret


;;; FM_CTX_2
;;; Set the current FM track to be FM2 for the next FM opcode processing
;;; ------
fm_ctx_2::
        ;; set new current FM channel
        ld      a, #1
        ld      (state_fm_channel), a
        ld      a, #1
        ret


;;; FM_CTX_3
;;; Set the current FM track to be FM3 for the next FM opcode processing
;;; ------
fm_ctx_3::
        ;; set new current FM channel
        ld      a, #2
        ld      (state_fm_channel), a
        ld      a, #1
        ret


;;; FM_CTX_4
;;; Set the current FM track to be FM4 for the next FM opcode processing
;;; ------
fm_ctx_4::
        ;; set new current FM channel
        ld      a, #3
        ld      (state_fm_channel), a
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
        ld      (state_fm_channel), a
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

        ;; e7: bit to target the right ym2610 port for channel
        ld      a, (state_fm_channel)
        cp      #2
        jr      c, _ops_channel12
        set     7, e
_ops_channel12:
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
        bit     7, e
        jr      z, _ops_port_a
        call    ym2610_write_port_b
        jr      _ops_next_op
_ops_port_a:
        call    ym2610_write_port_a
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

        ;;  configure writes to port a/b based on channel
        ld      a,b
        cp      #2
        jp      c, _fm_port_a
        jp      _fm_port_b

_fm_port_a:
        ;; a: start register in YM2610 for FM channel
        ld      a, #REG_FM1_OP1_DETUNE_MULTIPLY
        res     1, b
        add     b
_fm_port_a_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_a
        add     a, #NSS_FM_NEXT_REGISTER
        inc     hl
        dec     d
        jp      nz, _fm_port_a_loop
        ;;
        ld      d, #NSS_FM_END_OF_REGISTERS
        cp      d
        jp      nc, _fm_end
        ;; two additional properties a couples of regs away
        add     a, #NSS_FM_NEXT_REGISTER_GAP
        ld      d, #2
        jp      _fm_port_a_loop
        jp      _fm_end

_fm_port_b:
        ;; a: start register in ym2610 from FM channel
        ld      a, #REG_FM1_OP1_DETUNE_MULTIPLY
        res     1, b
        add     b
_fm_port_b_loop:
        ld      b, a
        ld      c, (hl)
        call    ym2610_write_port_b
        add     a, #NSS_FM_NEXT_REGISTER
        inc     hl
        dec     d
        jp      nz, _fm_port_b_loop
        ;;
        ld      d, #NSS_FM_END_OF_REGISTERS
        cp      d
        jp      nc, _fm_end
        ;; two additional properties a couples of regs away
        add     a, #NSS_FM_NEXT_REGISTER_GAP
        ld      d, #2
        jp      _fm_port_b_loop

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


;;; FM_NOTE_ON_EXT
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: FM channel
;;; [hl+1]: note (0xAB: A=octave B=semitone)
fm_note_on_ext::
        ;; set new current FM channel
        ld      a, (hl)
        ld      (state_fm_channel), a
        inc     hl
        jp      fm_note_on


;;; FM_NOTE_ON
;;; Emit a specific note (frequency) on an FM channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
fm_note_on::
        push    de

        ;; e: fm channel
        ld      a, (state_fm_channel)
        ld      e, a
        ;; d: note (0xAB: A=octave B=semitone)
        ld      d, (hl)
        inc     hl

        push    bc
        push    hl

        ;; stop FM channel
        ;; a: FM channel (YM2610 encoding)
        ld      a,e
        cp      #2
        jp      c, _fm_no_2_stop
        add     #2
_fm_no_2_stop:
        inc     a
        ;; stop all OP of FM channel
        and     #0xf
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        ;; a: note
        ld      a, d
        ;; d: block (octave)
        ld      b, a
        and     #0xf0
        sra     a
        ld      d, a
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
        ;; configure REG_FMx_BLOCK_FNUM_2
        ;; this is buffered by the YM2610 and must be set
        ;; before setting REG_FMx_BLOCK_FNUM_1
        ;; c: block | f_num MSB
        ld      a, h
        or      d
        ld      c, a
        ;; a: base f_num2 register in ym2610
        ld      a, #REG_FM1_BLOCK_FNUM_2
        ;; d: fm channel
        ld      d, e
        res     1, d
        add     d
        ;; b: f_num2 register for the FM channel
        ld      b, a
        ld      a, e
        ;; TODO MACRO: write_port_a_or_b
        cp      #2
        jp      c, _fm_fnum_2_port_a
        call    ym2610_write_port_b
        jp      _fm_post_fnum_2
_fm_fnum_2_port_a:
        call    ym2610_write_port_a
_fm_post_fnum_2:
        ;; END MACRO
        ;; configure REG_FMx_FNUM_1
        ld      a, b
        sub     #4
        ld      b, a
        ;; c: f_num LSB
        ld      c, l
        ld      a, e
        ;; TODO MACRO: write_port_a_or_b
        cp      #2
        jp      c, _fm_fnum_1_port_a
        call    ym2610_write_port_b
        jp      _fm_post_fnum_1
_fm_fnum_1_port_a:
        call    ym2610_write_port_a
_fm_post_fnum_1:
        ;; END MACRO

        ;; start FM channel
        ;; a: FM channel (YM2610 encoding)
        ld      a,e
        cp      #2
        jp      c, _fm_no_2_start
        add     #2
_fm_no_2_start:
        inc     a
        ;; start all OP of FM channel
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
        ld      (state_fm_channel), a

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
        ld      (state_fm_channel), a
        inc     hl
        jp      fm_note_off


;;; FM_NOTE_OFF
;;; Release the note on an FM channel. The sound will decay according
;;; to the current configuration of the FM channel's operators.
;;; ------
fm_note_off::
        push    bc

        ;; a: FM channel
        ld      a, (state_fm_channel)

        ;; a: YM2610-encoded FM channel
        cp      #2
        jp      c, _fm_off_no_2
        add     #2
_fm_off_no_2:
        inc     a

        ;; stop all OP of FM channel
        and     #0xf
        ld      c, a
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        call    ym2610_write_port_a

        pop     bc

        ;; FM context will now target the next channel
        ld      a, (state_fm_channel)
        inc     a
        ld      (state_fm_channel), a

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

        ;; TODO MACRO: write_port_a_or_b
        ld      a, e
        cp      #2
        jp      c, _opx_common_port_a
        call    ym2610_write_port_b
        jp      _opx_post_common
_opx_common_port_a:
        call    ym2610_write_port_a
_opx_post_common:
        ;; END MACRO

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
