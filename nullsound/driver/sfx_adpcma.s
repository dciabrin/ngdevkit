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

;;; The following driver is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=68k/Z80_communication


;;; sfx_adpcm_a_play
;;; ----------------
;;; Play a ROM sample on a YM2610 ADPCM-A channel
;;;
;;; Configuration: 6 bytes
;;;     .dw     0                   ; sample start addr >> 8
;;;     .dw     0                   ; sample stop addr >> 8
;;;     .db     0                   ; 2^(channel-1)
;;;     .db     0                   ; L/R output + volume

        ;; this macro is used by nullsound to load a config in memory
        .equ    sfx_adpcm_a_play_config_size, 6

        ;; private getters
        .equ    START_LSB, 0
        .equ    START_MSB, 1
        .equ    STOP_LSB, 2
        .equ    STOP_MSB, 3
        .equ    CHANNEL, 4
        .equ    VOLUME, 5



;;; action
;;; ------
;;; IN:
;;;    ix: state ptr in RAM
;;; OUT:
;;;    a == 1: playback is still ongoing
;;;    a == 0: playback has finished
;;;
sfx_adpcm_a_play:
        push    bc

        ;; have we been called already to play the sample? (volume==-1)
        ld      a, VOLUME(ix)
        cp      #0xff
        jr      nz, sfx_adpcm_a_configure
        ;; check if the playback is finished (port 6)
        in      a, (PORT_PLAYBACK_FINISHED)
        ld      b, CHANNEL(ix)
        and     b
        jr      z, sfx_adpcm_a_playback_running
sfx_adpcm_a_playback_finished:
        xor     a
        jr      sfx_adpcm_a_end
sfx_adpcm_a_playback_running:
        ld      a, #ACTION_RUNNING
        jr      sfx_adpcm_a_end
sfx_adpcm_a_configure:
        ;; stop channel playback, and reset the 'playback finished' flag
        ld      b, #REG_ADPCM_A_START_STOP
        ld      a, CHANNEL(ix)
        or      #0x80
        ld      c, a
        call    ym2610_write_port_b
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, CHANNEL(ix)
        call    ym2610_write_port_a
        ld      c, #0
        call    ym2610_write_port_a
        ;; prepare the sample addresses
        ld      a, #REG_ADPCM_A1_ADDR_START_LSB
        ld      b, CHANNEL(ix)
        ;; 2^exponent to offset
_sfx_adpcm_a_addr:
        srl     b
        jr      z, _sfx_adpcm_a_addr_end
        inc     a
        jr      _sfx_adpcm_a_addr
        ;; sample start LSB
_sfx_adpcm_a_addr_end:
        ld      b, a
        ld      c, START_LSB(ix)
        call    ym2610_write_port_b

        ;; sample start MSB
        add     a, #8
        ld      b, a
        ld      c, START_MSB(ix)
        call    ym2610_write_port_b

        ;; sample stop LSB
        add     a, #8
        ld      b, a
        ld      c, STOP_LSB(ix)
        call    ym2610_write_port_b

        ;; sample stop MSB
        add     a, #8
        ld      b, a
        ld      c, STOP_MSB(ix)
        call    ym2610_write_port_b

        ;; channel volume
        ld      a, #(REG_ADPCM_A1_VOL-1)
        add     a, CHANNEL(ix)
        ld      b, a
        ld      c, VOLUME(ix)
        call    ym2610_write_port_b

        ;; play channel
        ld      b, #REG_ADPCM_A_START_STOP
        ld      c, CHANNEL(ix)
        call    ym2610_write_port_b

        ;; yield to the mainloop
        ld      bc, #VOLUME
        add     ix, bc
        ld      (ix), #0xff
        ld      a, #ACTION_RUNNING
        ld      bc, #-VOLUME
        add     ix, bc
sfx_adpcm_a_end:
        pop     bc
        ret
