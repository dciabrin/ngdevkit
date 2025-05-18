;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2018-2023 Damien Ciabrini
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

;;; Implementation of the sound commands required by the BIOS

        .module nullsound

        .include "helpers.inc"
        .include "ports.inc"
        .include "ym2610.inc"

        .area   CODE

;;; Reserved commands as defined in the BIOS
;;; --------------------
;;; 00: <unused>
;;; 01: wait in RAM
;;; 02: play eye catcher music <provided by the game ROM>
;;; 03: init and start sound driver
;;;

;;; Unused sound command
snd_command_unused::
        retn

;;; Prepare for ROM switch on multi-cart board
;;; Stop sound and wait in RAM, to allow the 68k to switch
;;; cartridge (thus switch z80 ROM). Once done, the 68k will
;;; trigger sound request #3, to init the sound driver from
;;; the new ROM.
snd_command_01_prepare_for_rom_switch::
        di
        ;; Acknowledge command to the 68k
        xor     a
        out     (PORT_TO_68K), a
        out     (PORT_FROM_68K), a
        ;; reset the ym2610
        call    ym2610_reset
        ;; ;; build a jmp-to-self instruction in RAM
        prepare_wait_in_ram_opcodes
        ;; signal the 68k that we're ready
        ld      a, #1
        out     (PORT_TO_68K), a
        ;; return from NMI in top of RAM and loop there
        retn

;;; There is no default command 02, the game ROM should provide it
;; snd_command_02_eye_catcher_music

;;; Reset sound driver
;;; reset stack and start the sound driver
snd_command_03_reset_driver::
        ld      bc, #0
        jp      snd_init_driver_from_nmi
