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

        .area  CODE


;;; ADPCM_A_INSTRUMENT
;;; Configure an ADPCM-A channel based on an instrument's data
;;; ------
;;; [ hl ]: ADPCM-A channel
;;; [hl+1]: instrument number
adpcm_a_instrument::
        push    bc

        ;; b: ADPCM-A channel
        ld      b, (hl)
        inc     hl
        ;; a: instrument
        ld      a, (hl)
        inc     hl

        push    hl
        push    de
        ;; save ADPCM-A channel
        push    bc

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
        pop     bc

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

        pop     de
        pop     hl
        pop     bc
        ld      a, #1
        ret


;;; ADPCM_A_ON
;;; Start sound playback on a ADPCM-A channel
;;; ------
;;; [ hl ]: ADPCM-A channel
adpcm_a_on::
        push    bc
        push    de

        ;; d: ADPCM-A channel
        ld      d, (hl)
        inc     hl

        ;; TODO remove this default pan+volume
        ld      a, #REG_ADPCM_A1_PAN_VOLUME
        add     d
        ld      b, a
        ld      a, #0x1d        ; default vol
        or      #0xc0           ; default pan (L+R)
        ld      c, a
        call    ym2610_write_port_b

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
        ld      a, #1
        ret


;;; ADPCM_A_OFF
;;; Stop the playback on a ADPCM-A channel
;;; ------
;;; [ hl ]: ADPCM-A channel
adpcm_a_off::
        push    bc
        push    de

        ;; d: ADPCM-A channel
        ld      d, (hl)
        inc     hl

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

        ;; TODO remove this default pan
        ld      b, #REG_ADPCM_B_PAN
        ld      c, #0xc0        ; default pan (L+R)
        call    ym2610_write_port_a

        ;; TODO remove this default volume
        ld      b, #REG_ADPCM_B_VOLUME
        ld      c, #0xff        ; default vol
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
        ld      c, #0x80       ; start flag
        call    ym2610_write_port_a

        pop     hl
        pop     de
        pop     bc
        ld      a, #1
        ret
