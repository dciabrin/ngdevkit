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


        ;; load constants on a pair of Z80 registers
        .macro ldcst reg,car,cdr
        ld      'reg', (('car') << 8) | ('cdr')
        .endm

        ;; load constants on a pair of Z80 registers
        .macro init_unused_cmd_jmptable
cmd_jmptable_padding:
        ;; fill remaining commands if any
        .rept   128-((cmd_jmptable_padding - cmd_jmptable)/3)
        jp      snd_command_unused
        .endm
        .endm

        ;; nullsound ID, stored in the beginning of the sound ROM
        .macro  nullsound_id
        .ascii  %nullsound v0.2.0 - https://github.com/dciabrin/ngdevkit%
        .endm

        ;; private helper to generate z80 opcode to stay idle in RAM
        .lclequ RESET_WAIT_PC,0xfffe
        .lclequ OPCODE_JR_TO_SELF,0xfe18
        .macro  prepare_wait_in_ram_opcodes
        ;; create a jmp-to-self instruction at the top of the RAM
        ;; to ensure the 68k can bank-switch z80 code without impact
        ld      bc, #OPCODE_JR_TO_SELF     ; jr <self>
        ld      (#RESET_WAIT_PC), bc
        ;; ;; prepare the stack to pop into the jump-to-self in RAM
        ld      hl, #0xfffe
        ld      sp, hl
        push    hl
        .endm

        ;; address of an optional hook function that gets called
        ;; once the driver finished its initialization
        .lclequ POST_INIT_HOOK, RESET_WAIT_PC
