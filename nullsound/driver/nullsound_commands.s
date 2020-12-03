;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2020 Damien Ciabrini
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



;;; Unused sound command
snd_command_nop:
        jp      _end_nmi


;;; Prepare for ROM switch on multi-cart board
;;; Stop sound and wait in RAM, to allow the 68k to switch
;;; cartridge (thus switch z80 ROM). Once done, the 68k will
;;; trigger sound request #3, to init the sound driver from
;;; the new ROM.
snd_command_01_prepare_for_rom_switch:
        di
        ;; signal we're preparing the reset
        xor     a
        out     (PORT_TO_68K), a
        out     (PORT_FROM_68K), a
        ;; reset the ym2610
        call    snd_reset_ym2610
        ;; ;; build a jmp-to-self instruction in RAM
        ;; ld      bc, #0xfe18     ; jr <self>
        ;; ld      hl, #0xfffe
        ;; ld      sp, hl
        ;; push    bc
        ;; push    hl
        prepare_wait_in_ram_opcode
        ;; signal the 68k that we're ready
        ld      a, #1
        out     (0x0c), a
        ;; return from NMI in top of RAM and loop there
        retn


;;; TODO eye-catcher music
snd_command_02_eye_catcher_music:
        jp      _end_nmi


;;; Reset sound driver
;;; reset sp to top of RAM and pc to start of ROM
;;; the driver init will run from there
snd_command_03_reset_driver:
        di
        ld      sp, #0xffff
        ld      hl, #driver_init
        push    hl
        retn


;;; Reset ym2610
;;; mute the ym2610 and reset its master volume
snd_reset_ym2610:
        ld      b, #REG_ADPCM_A_START_STOP
        ld      a, #0x80        ; stop all channels
        call    ym2610_set_register_ports_6_7
        ld      b, #REG_ADPCM_A_MASTER_VOLUME
        ld      c, #0x3f        ; loudest
        call    ym2610_set_register_ports_6_7
        ret


;;; Register a sound request for processing after the NMI
;;; push the request from the m68k to the list of pending sound requests
;;; the processing is delayed to allow the 68k to wait as few as possible
snd_push_pending_request:
        exx
        ;; bump the pending offset
        ld      a, (snd_requests_pending_offset)
        inc     a
        and     a, #(MAX_PENDING_REQUESTS-1)
        ld      (snd_requests_pending_offset), a
        ld      de, #snd_requests
        add     e
        ld      e, a
        ;; record the pending sound request
        in      a, (PORT_FROM_68K)
        ld      (de), a
        ;; acknowledge the sound request to the 68k
        set     7, a
        out     (PORT_TO_68K), a
        exx
        jp      _end_nmi


;;; Process the pending sound requests
;;; For every pending request, run its the associated sound command
;;; which results in configuring a module to execute a new sound action
snd_process_pending_requests:
        ld      a, (snd_requests_pending_offset)
        ld      b, a
        ld      a, (snd_requests_current_offset)
        cp      b
        jr      z, _snd_no_pending_requests
        push    hl
_snd_loop_requests:
        inc     a
        and     a, #(MAX_PENDING_REQUESTS-1)
        ld      (snd_requests_current_offset), a
        ;; de <- pending_requests[current_offset]
        ld      de, #snd_requests
        add     e
        ld      e, a
        ;; hl <- cmd_jmptable[sound request]
        ld      a, (de)
        ld      b, #0
        ld      c, a
        ld      l, c
        ld      h, b
        add     hl, hl
        add     hl, bc
        ld      bc, #cmd_jmptable
        add     hl, bc
        ;; call the command
        ld      bc, #_snd_ret_from_jmptable
        push    bc
        push    hl
        ret
_snd_ret_from_jmptable:
        ld      a, (snd_requests_pending_offset)
        ld      b, a
        ld      a, (snd_requests_current_offset)
        cp      b
        jr      nz, _snd_loop_requests
        pop     hl
_snd_no_pending_requests:
        ret
