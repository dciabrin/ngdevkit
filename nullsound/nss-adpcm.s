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

        .equ    NSS_ADPCM_A_INSTRUMENT_PROPS,   4
        .equ    NSS_ADPCM_A_NEXT_REGISTER,      8

        .equ    NSS_ADPCM_B_INSTRUMENT_PROPS,   4
        .equ    NSS_ADPCM_B_NEXT_REGISTER,      8



        .area  DATA

;;; ADPCM playback state tracker
;;; ------
_state_adpcm_start:

;;; context: current adpcm channel for opcode actions
state_adpcm_a_channel::
        .db     0

;;; current ADPCM-B instrumment play command (with loop)
state_adpcm_b_start_cmd::
        .db     0

;;; current volumes for ADPCM-A channels
state_adpcm_a_vol::     .blkb   6
;;; current volumes for ADPCM-B channel
state_adpcm_b_vol::     .blkb   1

_state_adpcm_end:

        .area  CODE

;;;  Reset ADPCM playback state.
;;;  Called before playing a stream
;;; ------
;;; [a modified - other registers saved]
init_nss_adpcm_state_tracker::
        ld      a, #0
        ld      (state_adpcm_a_channel), a
        ld      a, #0x80       ; start flag
        ld      (state_adpcm_b_start_cmd), a
        ;; default volumes
        ld      a, #0x1f
        ld      (state_adpcm_a_vol), a
        ld      (state_adpcm_a_vol+1), a
        ld      (state_adpcm_a_vol+2), a
        ld      (state_adpcm_a_vol+3), a
        ld      (state_adpcm_a_vol+4), a
        ld      (state_adpcm_a_vol+5), a
        ld      a, #0xff
        ld      (state_adpcm_b_vol), a
        ret

;;;  Reset ADPCM-A playback state.
;;;  Called before waiting for the next tick
;;; ------
;;; [a modified - other registers saved]
adpcm_a_ctx_reset::
        ld      a, #0
        ld      (state_adpcm_a_channel), a
        ret


;;; ADPCM NSS opcodes
;;; ------

;;; ADPCM_A_CTX_1
;;; Set the current ADPCM-A context to channel 1 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_1::
        ;; set new current FM channel
        ld      a, #0
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_CTX_2
;;; Set the current ADPCM-A context to channel 2 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_2::
        ;; set new current ADPCM-A channel
        ld      a, #1
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_CTX_3
;;; Set the current ADPCM-A context to channel 3 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_3::
        ;; set new current ADPCM-A channel
        ld      a, #2
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_CTX_4
;;; Set the current ADPCM-A context to channel 4 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_4::
        ;; set new current ADPCM-A channel
        ld      a, #3
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_CTX_5
;;; Set the current ADPCM-A context to channel 5 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_5::
        ;; set new current ADPCM-A channel
        ld      a, #4
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_CTX_6
;;; Set the current ADPCM-A context to channel 6 ADPCM-A opcode processing
;;; ------
adpcm_a_ctx_6::
        ;; set new current ADPCM-A channel
        ld      a, #5
        ld      (state_adpcm_a_channel), a
        ld      a, #1
        ret


;;; ADPCM_A_INSTRUMENT_EXT
;;; Configure an ADPCM-A channel based on an instrument's data
;;; ------
;;; [ hl ]: ADPCM-A channel
;;; [hl+1]: instrument number
adpcm_a_instrument_ext::
        ;; set new current ADPCM-A channel
        ld      a, (hl)
        ld      (state_adpcm_a_channel), a
        inc     hl
        jp      adpcm_a_instrument


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

        ;; b: volume register for this channel
        ld      a, #REG_ADPCM_A1_PAN_VOLUME
        add     d
        ld      b, a

        ;; c: current channel volume (8bit add)
        ld      hl, #state_adpcm_a_vol
        ld      a, l
        add     d
        ld      l, a
        ld      a, (hl)
        or      #0xc0           ; default pan (L+R)
        ld      c, a

        call    ym2610_write_port_b

        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; ADPCM_A_ON_EXT
;;; Start sound playback on a ADPCM-A channel
;;; ------
;;; [ hl ]: ADPCM-A channel
adpcm_a_on_ext::
        ;; set new current ADPCM-A channel
        ld      a, (hl)
        ld      (state_adpcm_a_channel), a
        inc     hl
        jp      adpcm_a_on


;;; ADPCM_A_ON
;;; Start sound playback on a ADPCM-A channel
;;; ------
adpcm_a_on::
        push    bc
        push    de

        ;; d: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        ld      d, a

        ;; a: bitwise channel
        ld      a, #0
        inc     d
        scf
_on_bit:
        rla
        dec     d
        jp      nz, _on_bit

        ;; start channel
        ld      b, #REG_ADPCM_A_START_STOP
        ld      c, a
        call    ym2610_write_port_b

        pop     de
        pop     bc

        ;; ADPCM-A context will now target the next channel
        ld      a, (state_adpcm_a_channel)
        inc     a
        ld      (state_adpcm_a_channel), a

        ld      a, #1
        ret


;;; ADPCM_A_OFF_EXT
;;; Stop the playback on a ADPCM-A channel
;;; ------
;;; [ hl ]: ADPCM-A channel
adpcm_a_off_ext::
        ;; set new current ADPCM-A channel
        ld      a, (hl)
        ld      (state_adpcm_a_channel), a
        inc     hl
        jp      adpcm_a_off


;;; ADPCM_A_OFF
;;; Stop the playback on a ADPCM-A channel
;;; ------
adpcm_a_off::
        push    bc
        push    de

        ;; d: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
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

        ;; ADPCM-A context will now target the next channel
        ld      a, (state_adpcm_a_channel)
        inc     a
        ld      (state_adpcm_a_channel), a

        ld      a, #1
        ret


;;; ADPCM_A_VOL
;;; Set playback volume of the current ADPCM-A channel
;;; ------
adpcm_a_vol::
        push    bc

        ;; c: volume
        ld      c, (hl)
        inc     hl

        push    hl

        ;; hl: current volume for channel (bit add)
        ld      hl, #state_adpcm_a_vol
        ld      a, (state_adpcm_a_channel)
        add     l
        ld      l, a
        ;; update current volume for channel
        ld      a, c
        ld      (hl), a

        ;; b: ADPCM-A channel
        ld      a, (state_adpcm_a_channel)
        add     a, #REG_ADPCM_A1_PAN_VOLUME
        ld      b, a

        ;; c: volume + default pan (L/R)
        ld      a, c
        or      #0xc0
        ld      c, a

        ;; set volume for channel in the YM2610
        call    ym2610_write_port_b

        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; ADPCM_B_INSTRUMENT
;;; Configure the ADPCM-B channel based on an instrument's data
;;; ------
;;; [ hl ]: instrument number
adpcm_b_instrument::
        ;; a: instrument
        ld      a, (hl)
        inc     hl

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
        ld      (state_adpcm_b_start_cmd), a

        ;; set a default pan
        ld      b, #REG_ADPCM_B_PAN
        ld      c, #0xc0        ; default pan (L+R)
        call    ym2610_write_port_a

        ;;  current volume
        ld      b, #REG_ADPCM_B_VOLUME
        ld      a, (state_adpcm_b_vol)
        ld      c, a
        call    ym2610_write_port_a

        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; Semitone frequency table
;;; ------
;;; A note in nullsound is represented as a tuple <octave, semitone>,
;;; which is translated into YM2610's register representation
;;; `Delta-N`. nullsounds decomposes Delta-N as `2^octave * base`,
;;; where base is a factor of the semitone's frequency, and the
;;; result is multiplied by a power of 2 (handy for octaves)
adpcm_b_note_base_delta_n:
        .db     0x0c, 0xb7	; 3255 - C
        .db     0x0d, 0x78	; 3448 - C#
        .db     0x0e, 0x45	; 3653 - D
        .db     0x0f, 0x1f	; 3871 - D#
        .db     0x10, 0x05	; 4101 - E
        .db     0x10, 0xf9	; 4345 - F
        .db     0x11, 0xfb	; 4603 - F#
        .db     0x13, 0x0d	; 4877 - G
        .db     0x14, 0x2f	; 5167 - G#
        .db     0x15, 0x62	; 5474 - A
        .db     0x16, 0xa8	; 5800 - A#
        .db     0x18, 0x00	; 6144 - B


;;; ADPCM_B_NOTE_ON
;;; Emit a specific note (sample frequency) on the ADPCM-B channel
;;; ------
;;; [ hl ]: note (0xAB: A=octave B=semitone)
adpcm_b_note_on::
        push    bc
        push    de

        ;; d: note  (0xAB: A=octave B=semitone)
        ld      d, (hl)
        inc     hl

        push    hl

        ;; stop the ADPCM-B channel
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #1           ; reset flag (clears start and repeat in YM2610)
        call    ym2610_write_port_a

        ;; a: semitone
        ld      a, d
        and     #0xf

        ;; d: octave
        srl     d
        srl     d
        srl     d
        srl     d

        ;; lh: semitone -> delta_n address
        ld      hl, #adpcm_b_note_base_delta_n
        sla     a
        ld      b, #0
        ld      c, a
        add     hl, bc

        ;; bc: base delta_n
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl

        ;; hl: delta_n (base << octave)
        ;; d: octave
        push    bc
        pop     hl

        ld      a, d
        cp      #0
        jp      z, _no_delta_shift
_delta_shift:
        add     hl, hl
        dec     d
        jp      nz, _delta_shift
_no_delta_shift:

        ;; de: delta_n
        push    hl
        pop     de

        ;; configure delta_n into the YM2610
        ld      b, #REG_ADPCM_B_DELTA_N_LSB
        ld      c, e
        call    ym2610_write_port_a
        ld      b, #REG_ADPCM_B_DELTA_N_MSB
        ld      c, d
        call    ym2610_write_port_a

        ;; start the ADPCM-B channel
        ld      b, #REG_ADPCM_B_START_STOP
        ;; start command (with loop when configured)
        ld      a, (state_adpcm_b_start_cmd)
        ld      c, a
        call    ym2610_write_port_a

        pop     hl
        pop     de
        pop     bc
        ld      a, #1
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

        pop     bc
        ld      a, #1
        ret


;;; ADPCM_B_VOL
;;; Set playback volume of the ADPCM-B channel
;;; ------
adpcm_b_vol::
        push    bc

        ;; a: volume
        ld      a, (hl)
        inc     hl

        ;; new configured volume for ADPCM-B
        ld      (state_adpcm_b_vol), a

        ;; set volume in the YM2610
        ld      b, #REG_ADPCM_B_VOLUME
        ld      c, a
        call    ym2610_write_port_a

        pop     bc
        ld      a, #1
        ret
