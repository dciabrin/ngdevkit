;;;
;;; nullsound - bare sound driver
;;; Copyright (c) 2018 Damien Ciabrini
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

        .area _HEADER (ABS)
        ;; at boot, jump in RAM and wait for the 68k
        di
        jp      stayinram

        ;; interupt handler
        .org    0x0066
        in      a, (0x00)
        cp      #1
        jp      z, snd_command_01
        cp      #3
        jp      z, snd_command_03

stayinram:
        ;; Build a "jump to self" opcode in RAM
        ld      hl,#0xfffd
        ld      (hl),#0xc3      ; (fffd)=$c3, opcode for jp
        ld      (0xfffe),hl     ; (fffe)=$fffd (makes "jp fffd")
        ei
        ld      a,#0x01
        out     (0x0c),a        ; Tell 68k that we're ready
        jp      0xfffd          ; Quickly jump to RAM loop


snd_command_01:
        di                      ; Disable interrupts
        xor     a
        out     (0x0c), a       ; Clear both buffers
        out     (0x00), a
        ld      sp, #0xfffc     ; Reset sp
        ld      hl, #stayinram
        push    hl
        retn                    ; retn to stayinram

snd_command_03:
        di                      ; Disable interrupts
        ld      sp, #0xffff     ; Clear call stack
        ld      hl, #0
        push    hl
        retn                    ; retn to 0
