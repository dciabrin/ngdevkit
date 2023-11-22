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

;;; The following driver is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=68k/Z80_communication

        .module nullsound

        .include "ym2610.inc"
        .include "ports.inc"


;;;
;;; ADPCM state tracker
;;; -------------------
;;; keep track of the YM2610 ADPCM channels
;;;
        .area  DATA

;;; Maintains one bit per ADPCM channel currently playing
;;; | B  | __ | A6 | A5 | A4 | A3 | A2 | A1 |
state_adpcm_busy:
        .db     0x00


        .area  CODE

init_adpcm_state_tracker::
        ld      a, #0
        ld      (state_adpcm_busy), a
        ret

update_adpcm_state_tracker::
        ;; stopped channels get their bit set to 0
        in      a, (PORT_PLAYBACK_FINISHED)
        or      a
        jp      z, _adpcm_no_state_update
        ;; reset and mask stop flag for stopped channels
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, a
        call    ym2610_write_port_a
        ;; unmask all channels to get notified of next playback stops
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, #0x00
        call    ym2610_write_port_a
        ;; a <- busy state clear mask
        cpl
        ld      b, a
        ld      a, (state_adpcm_busy)
        and     b
        ld      (state_adpcm_busy), a
_adpcm_no_state_update:
        ret



;;;
;;; ADPCM functions
;;; ---------------
;;;

;;; Input for `Play ROM sample` functions below
        .equ    A_START_LSB,    0 ; start address * 0x100 in ROM (LSB)
        .equ    A_START_MSB,    1 ; start address * 0x100 in ROM (MSB)
        .equ    A_STOP_LSB,     2 ; stop address * 0x100 in ROM (LSB)
        .equ    A_STOP_MSB,     3 ; stop address * 0x100 in ROM (MSB)
        .equ    A_CHANNEL,      4 ; channel (0..5)
        .equ    A_PAN_VOLUME,   5 ; channel L/R ouput + volume
        .equ    A_CHANNEL_BIT,  6 ; channel (2^(channel-1))

        .equ    B_START_LSB,    0 ; start address * 0x100 in ROM (LSB)
        .equ    B_START_MSB,    1 ; start address * 0x100 in ROM (MSB)
        .equ    B_STOP_LSB,     2 ; stop address * 0x100 in ROM (LSB)
        .equ    B_STOP_MSB,     3 ; stop address * 0x100 in ROM (MSB)
        .equ    B_DELTA_N_LSB,  4 ; Delta-N (LSB)
        .equ    B_DELTA_N_MSB,  5 ; Delta-N (MSB)
        .equ    B_PAN,          6 ; L/R ouput
        .equ    B_VOLUME,       7 ; volume


;;; Play a ROM sample on a ADPCM-A channel
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_a_play::
        push    bc
        ;; stop playback
        ld      b, #REG_ADPCM_A_START_STOP
        ld      a, A_CHANNEL_BIT(ix)
        or      #0x80
        ld      c, a
        call    ym2610_write_port_b
        ;; reset the 'playback finished' flag
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, A_CHANNEL_BIT(ix)
        call    ym2610_write_port_a
        ld      c, #0
        call    ym2610_write_port_a
        ;; sample start LSB
        ld      a, #REG_ADPCM_A1_ADDR_START_LSB
        ld      b, A_CHANNEL(ix)
        add     b               ; REG_ADPCM_A<channel>_ADDR_START_LSB
        ld      b, a
        ld      c, A_START_LSB(ix)
        call    ym2610_write_port_b
        ;; sample start MSB
        add     a, #8           ; REG_ADPCM_A<channel>_ADDR_START_MSB
        ld      b, a
        ld      c, A_START_MSB(ix)
        call    ym2610_write_port_b
        ;; sample stop LSB
        add     a, #8           ; REG_ADPCM_A<channel>_ADDR_STOP_LSB
        ld      b, a
        ld      c, A_STOP_LSB(ix)
        call    ym2610_write_port_b
        ;; sample stop MSB
        add     a, #8           ; REG_ADPCM_A<channel>_ADDR_STOP_MSB
        ld      b, a
        ld      c, A_STOP_MSB(ix)
        call    ym2610_write_port_b
        ;; channel pan and volume
        ld      a, #REG_ADPCM_A1_PAN_VOLUME
        add     a, A_CHANNEL(ix)  ; REG_ADPCM_A<channel>_VOL
        ld      b, a
        ld      c, A_PAN_VOLUME(ix)
        call    ym2610_write_port_b
        ;; play channel
        ld      b, #REG_ADPCM_A_START_STOP
        ld      c, A_CHANNEL_BIT(ix)
        call    ym2610_write_port_b
        ;; mark the channel as busy
        ld      a, (state_adpcm_busy)
        or      c
        ld      (state_adpcm_busy), a
_snd_adpcm_a_end:
        pop     bc
        ret


;;; Play a ROM sample on a ADPCM-A channel only if it's not in use
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_a_play_exclusive::
        push    bc
        ld      a, (state_adpcm_busy)
        ld      b, A_CHANNEL_BIT(ix)
        and     b
        jp      nz, _snd_adpcm_a_busy
        ;; play sample (will mark the channel as busy)
        call    snd_adpcm_a_play
_snd_adpcm_a_busy:
        pop     bc
        ret


;;; Configure a ROM sample on the ADPCM-B channel for playback
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_b_play_common::
        ;; stop playback
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #0x01
        call    ym2610_write_port_a
        ;; reset the 'playback finished' flag
        ld      b, #REG_ADPCM_PLAYBACK_MASK
        ld      c, #0x80
        call    ym2610_write_port_a
        ld      c, #0x00
        call    ym2610_write_port_a
        ;; sample start LSB
        ld      b, #REG_ADPCM_B_ADDR_START_LSB
        ld      c, B_START_LSB(ix)
        call    ym2610_write_port_a
        ;; sample start MSB
        ld      b, #REG_ADPCM_B_ADDR_START_MSB
        ld      c, B_START_MSB(ix)
        call    ym2610_write_port_a
        ;; sample stop LSB
        ld      b, #REG_ADPCM_B_ADDR_STOP_LSB
        ld      c, B_STOP_LSB(ix)
        call    ym2610_write_port_a
        ;; sample stop MSB
        ld      b, #REG_ADPCM_B_ADDR_STOP_MSB
        ld      c, B_STOP_MSB(ix)
        call    ym2610_write_port_a
        ;; Delta-N LSB
        ld      b, #REG_ADPCM_B_DELTA_N_LSB
        ld      c, B_DELTA_N_LSB(ix)
        call    ym2610_write_port_a
        ;; Delta-N MSB
        ld      b, #REG_ADPCM_B_DELTA_N_MSB
        ld      c, B_DELTA_N_MSB(ix)
        call    ym2610_write_port_a
        ;; channel pan
        ld      b, #REG_ADPCM_B_PAN
        ld      c, B_PAN(ix)
        call    ym2610_write_port_a
        ;; channel volume
        ld      b, #REG_ADPCM_B_VOLUME
        ld      c, B_VOLUME(ix)
        call    ym2610_write_port_a
        ret


;;; Play a ROM sample on the ADPCM-B channel
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_b_play::
        push    bc
        call    snd_adpcm_b_play_common
        ;; play channel
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #0x80
        call    ym2610_write_port_a
        ;; mark the channel as busy
        ld      a, (state_adpcm_busy)
        ld      c, #0x80
        or      c
        ld      (state_adpcm_busy), a
        pop     bc
        ret


;;; Play and loop a ROM sample on the ADPCM-B channel
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_b_play_loop::
        push    bc
        call    snd_adpcm_b_play_common
        ;; play channel
        ld      b, #REG_ADPCM_B_START_STOP
        ld      c, #0x90
        call    ym2610_write_port_a
        ;; mark the channel as busy
        ld      a, (state_adpcm_busy)
        ld      c, #0x80
        or      c
        ld      (state_adpcm_busy), a
        pop     bc
        ret


;;; Play a ROM sample on the ADPCM-B channel only if it's not in use
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_b_play_exclusive::
        push    bc
        ld      a, (state_adpcm_busy)
        ld      b, #0x80
        and     b
        jp      nz, _snd_adpcm_b_busy
        ;; play sample (will mark the channel as busy)
        call    snd_adpcm_b_play
_snd_adpcm_b_busy:
        pop     bc
        ret


;;; Play and loop a ROM sample on the ADPCM-B channel only if it's not in use
;;; ------
;;; ix: sample play config
;;; [a modified - other registers saved]
snd_adpcm_b_play_loop_exclusive::
        push    bc
        ld      a, (state_adpcm_busy)
        ld      b, #0x80
        and     b
        jp      nz, _snd_adpcm_b_loop_busy
        ;; play sample (will mark the channel as busy)
        call    snd_adpcm_b_play_loop
_snd_adpcm_b_loop_busy:
        pop     bc
        ret
