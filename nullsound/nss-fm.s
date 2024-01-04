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

;;; NSS opcode for FM channels
;;;

        .module nullsound

        .include "ym2610.inc"

        .equ    NSS_FM_INSTRUMENT_PROPS,        28
        .equ    NSS_FM_NEXT_REGISTER,           4
        .equ    NSS_FM_NEXT_REGISTER_GAP,       16
        .equ    NSS_FM_END_OF_REGISTERS,        0xb7



        .area  DATA

;;; FM playback state tracker
;;; ------

;;; context: current fm channel for opcode actions
state_fm_channel::
        .db     0



        .area  CODE
;;;  Reset FM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_fm_state_tracker::
        ld      a, #0
        ld      (state_fm_channel), a
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
        ld      a, (state_fm_channel)
        ld      b, a

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
        pop     de
        pop     hl
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
        ;; lh: semitone -> f_num address
        ld      hl, #fm_note_f_num
        sla     a
        ld      b, #0
        ld      c, a
        add     hl, bc
        ;; configure REG_FMx_BLOCK_FNUM_2
        ld      a, (hl)
        inc     hl
        or      d
        ld      c, a
        ld      a, #0xa5
        ld      d, e
        res     1, d
        add     d
        ld      b, a
        ld      a,e
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
        ld      a, (hl)
        inc     hl
        ld      c, a
        ld      a,e
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
