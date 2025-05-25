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

;;; Z80 initialization into sound driver main loop

        .module nullsound

        .include "helpers.inc"
        .include "ports.inc"
        .include "ym2610.inc"

        .equ     START_OF_STACK, 0xfffd
        .equ     MAX_PENDING_COMMANDS, 64



;;;
;;; Absolute Z80 startup code
;;; -------------------------
;;;
        .area START (ABS)
        di
        jp      init_z80_and_wait

;;; Restart handlers. An custom jump-table to the most called functions
;;; in this Z80 ROM. Accessed with the `RST` opcode, which is slightly
;;; faster and space-efficient than a regular `CALL` opcode.
;;;
        .org    0x0008
        ret                     ; unused
        .org    0x0010
        ret                     ; unused
        .org    0x0018
        ret                     ; unused
        .org    0x0020
        ret                     ; unused
        .org    0x0028
        ret                     ; unused
        .org    0x0030
        ret                     ; unused

;;; INT handler for the two interrupts triggered by the YM2610
;;; (fixed address 0x0038 when the Z80 uses Interrupt Mode 1)
;;;
        .org    0x0038
        di
        call    update_timer_state_tracker
        ei
        reti

;;; NMI handler (fixed address 0x0066 in the Z80)
;;;
        .org    0x0066
        ;; common driver commands
        ex      af, af'
        in      a, (PORT_FROM_68K)
        cp      #1
        jp      z, snd_command_01_prepare_for_rom_switch
        cp      #3
        jp      z, snd_command_03_reset_driver
        ;; else register the commands for later processing
        jp      snd_push_pending_command
        retn


;;; nullsound marker, for identification (or for fun)
;;;
        .org    0x00c0
        nullsound_id

;;; The rest of the code is linked in the CODE area, starting
;;; at address 0x0100, to not overwrite the segment START above

        .area CODE
        . = . + 0x0100


;;; Z80 startup code
;;; ----------------
;;; This performs a very minimal Z80 initialization to quickly
;;; mute the ym2610 and to stay idle in RAM until the 68k sets up
;;; the proper Z80 ROM and triggers the sound driver initialization
;;;
init_z80_and_wait:
        ;; Configure the Z80 for interrupt mode 1 (fixed handler @ 0x0038)
        im      1

        ;; Before init, the Z80 must stay idle in RAM. This allows multi-slot
        ;; MVS cabinets to switch game and map the game's sound ROM in the
        ;; Z80 address space.
        ;; The real init starts when the Z80 receives a NMI from the 68k
        ;; (it will only receive NMIs once the Z80 ports mapped to
        ;; bankswitching have been written to)
        xor     a
        out     (PORT_ENABLE_NMI), a

        ;; We don't have time to run much code before the 68k fire a NMI,
        ;; so do not try to mute YM2610 here

        ;; Returns to RAM and busy-loop until a NMI is triggered and proceeds
        ;; with the rest of the driver initialization
        prepare_wait_in_ram_opcodes
        ret


;;; Intialize and start the sound driver
;;; This function is called during a NMI, this is the last
;;; function called from the NMI before starting the driver
;;; ------
;;; [ bc ]: optional hook, called after the driver is initialized
snd_init_driver_from_nmi::
        di
        ld      (#POST_INIT_HOOK), bc
        ld      sp, #START_OF_STACK
        ld      hl, #snd_start_driver
        push    hl
        retn


;;; Sound driver
;;; ------------
;;; This is a simple state machine:
;;;  . process pending commands received via NMI
;;;  . update the various state trackers
;;;     . interrupts received
;;;     . state of the ym2610 (ADPCM playing...)
;;;     . long running tasks (music player, volume fading...)
;;;
snd_start_driver::
        ;; mute the YM2610
        call    ym2610_reset

        ;; reset Z80 memory layout to map the first 64KB of ROM
        ld      bc, #bank_64k_linear
        call    bank_switch

        ;; init the state trackers
        call    init_timer_state_tracker
        call    init_adpcm_state_tracker
        call    init_stream_state_tracker
        call    init_volume_state_tracker

        ;; reset the pending commands buffer
        xor     a
        ld      (command_fifo_current), a
        ld      (command_fifo_pending), a

        ;; if there is a post-hook function configured, run it
        ;; now before entering the main loop
        ld      hl, (#POST_INIT_HOOK)
        ld      a, h
        or      l
        jr      z, snd_mainloop
        ld      bc, #snd_mainloop
        push    bc
        push    hl
        ret

snd_mainloop:
        ;; process pending commands if any
        call    snd_process_pending_commands

        ;; Update the state trackers
        call    update_stream_state_tracker
        call    update_adpcm_state_tracker
        call    update_volume_state_tracker
        ;; TODO: CD state tracker

        jp      snd_mainloop

;;;
;;; Sound driver API
;;;

;;; Register a sound request for processing after the NMI
;;; push the request from the m68k to the list of pending sound requests
;;; the processing is delayed to allow the 68k to wait as few as possible
snd_push_pending_command:
        exx
        ;; bump the pending offset
        ld      a, (command_fifo_pending)
        inc     a
        and     a, #(MAX_PENDING_COMMANDS-1)
        ld      (command_fifo_pending), a
        ld      de, #command_fifo
        add     e
        ld      e, a
        ;; record the pending sound request
        in      a, (PORT_FROM_68K)
        ld      (de), a
        ;; acknowledge the sound request to the 68k
        set     7, a
        out     (PORT_TO_68K), a
        exx
        ;; restore af (captured at the start of the NMI)
        ex      af', af
        retn

;;; Process the pending commands received from NMI
snd_process_pending_commands:
        ld      a, (command_fifo_pending)
        ld      b, a
        ld      a, (command_fifo_current)
        cp      b
        jr      z, _no_pending_commands
        push    hl
_loop_commands:
        inc     a
        and     a, #(MAX_PENDING_COMMANDS-1)
        ld      (command_fifo_current), a
        ;; get next command to process
        ;;   a <- command_fifo[current]
        ld      de, #command_fifo
        add     e
        ld      e, a
        ld      a, (de)
        ;; retrieve command address in the jump table
        ;;   hl <- &cmd_jmptable[a]
        ld      b, #0
        ld      c, a
        ld      l, c
        ld      h, b
        add     hl, hl
        add     hl, bc
        ld      bc, #cmd_jmptable
        add     hl, bc
        ;; call the command
        ld      bc, #_ret_from_cmd
        push    bc
        push    hl
        ret
_ret_from_cmd:
        ld      a, (command_fifo_pending)
        ld      b, a
        ld      a, (command_fifo_current)
        cp      b
        jr      nz, _loop_commands
        pop     hl
_no_pending_commands:
        ret

        ;; inline the definition of various global precalc tables, to
        ;; speed up the 16bit indexing at runtime.
        ;; TODO(find a clean asxxxx/asmlnk way to do that)
        .include "buffers.s"



;;; Sound driver state in memory
;;; ----------------------------
;;;
        .area  DATA

;;; The ring buffer of the pending sound requests
;;; size is a power of 2, and must be aligned in memory so that
;;; the entire buffer fits in a single MSB address
command_fifo:
        .blkb   MAX_PENDING_COMMANDS
;;; offset of the last processed command in the ring buffer
command_fifo_current:
        .blkb   1
;;; all the offsets past current_offset up to pending_offset
;;; are sound requests to be processed
command_fifo_pending:
        .blkb   1
