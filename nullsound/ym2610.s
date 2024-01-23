;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2020-2023 Damien Ciabrini
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

        .module nullsound

        .include "ports.inc"
        .include "ym2610.inc"

        .area CODE


;;; ym2610_write_port_a
;;; -------------------
;;; IN:
;;;    b: register address in ym2610
;;;    c: data to set
;;; (all registers are preserved)
ym2610_write_port_a::
        push    af
        ;; select register address
        ld      a, b
        out     (PORT_YM2610_A_ADDR), a
        call    _ym2610_wait_address_write
        ;; set data in the selected register
        ld      a, c
        out     (PORT_YM2610_A_VALUE), a
        call    _ym2610_wait_data_write
        pop     af
        ret

;;; ym2610_write_port_b
;;; -------------------
;;; IN:
;;;    b: register address in ym2610
;;;    c: data to set
;;; (all registers are preserved)
ym2610_write_port_b::
        push    af
        ;; select register address
        ld      a, b
        out     (PORT_YM2610_B_ADDR), a
        call    _ym2610_wait_address_write
        ;; set data in the selected register
        ld      a, c
        out     (PORT_YM2610_B_VALUE), a
        call    _ym2610_wait_data_write
        pop     af
        ret

;;; From https://wiki.neogeodev.org/index.php?title=Z80/YM2610_interface
;;; YM2610 requires at least 2.125us before accepting another write
;;; call + nop + ret = 24 T-cycles (6us?)
_ym2610_wait_address_write:
        nop
        ret

;;; From https://wiki.neogeodev.org/index.php?title=Z80/YM2610_interface
;;; YM2610 requires at least 10.375us before accepting another write
;;; call + pushes + ret = 83 T-cycles (20.75us?)
_ym2610_wait_data_write:
        push    bc
        push    de
        push    hl
        pop     hl
        pop     de
        pop     bc
        ret




;;; Reset YM2610
;;; ------------
;;; Reset ym2610 timers, channels playback and volumes
ym2610_reset::
        push    bc
        push    de

        ;; reset all timers
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x30
        call    ym2610_write_port_a

        ;; FM playback can't be reset, the quickest way of stopping
        ;; sound output from a channel is to configure its OPs for a
        ;; very fast release rate and "key off" the channel's OPs.
        ;; This helps prevent a "pop" noise when a music is restarted
        ;; too quickly after ym2610_reset and operators's level are
        ;; reconfigured while a note release is still ongoing.
        ld      d, #4
        ld      e, d
        ld      a, #REG_FM1_OP1_SUSTAIN_LEVEL_RELEASE_RATE
        ld      b, a
        ld      c, #0x1f        ; sustain level: 1, release rate: 15
_release_ops:
        call    ym2610_write_port_a
        call    ym2610_write_port_b
        inc     b
        call    ym2610_write_port_a
        call    ym2610_write_port_b
        add     a, e
        ld      b, a
        dec     d
        jp      nz, _release_ops

        ;; stop note of all FM channels
        ld      b, #REG_FM_KEY_ON_OFF_OPS
        ld      c, #YM2610_FM1
        call    ym2610_write_port_a
        ld      c, #YM2610_FM2
        call    ym2610_write_port_a
        ld      c, #YM2610_FM3
        call    ym2610_write_port_a
        ld      c, #YM2610_FM4
        call    ym2610_write_port_a

        ;; ADPCM-A
        ld      b, #REG_ADPCM_A_START_STOP
        ld      c, #0xbf        ; stop all channels A
        call    ym2610_write_port_b
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, #0x3f        ; reset and mask stop flag: all channels A
        call    ym2610_write_port_a
        ld      b, #REG_ADPCM_A_MASTER_VOLUME
        ld      c, #0x3f        ; loudest
        call    ym2610_write_port_b
        ;; ADPCM-B
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #0x01        ; channel B reset (stop)
        call    ym2610_write_port_a
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #0x00        ; channel B no start, no repeat
        call    ym2610_write_port_a
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, #0x80        ; reset and mask stop flag: channel B
        call    ym2610_write_port_a
        ;; once all ADPCM channels are stopped and their stop flag is reset
        ;; unmask them to allow the driver to get notified of future stops
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, #0x00        ; unmask all channels
        call    ym2610_write_port_a

        pop     de
        pop     bc
        ret
