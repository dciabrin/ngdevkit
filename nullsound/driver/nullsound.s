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

;;; The following driver is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=68k/Z80_communication


;;; This file is the generic driver entry point. It depends on
;;; an external file that provides the defines and macros that
;;; are necessary to compile a custom nullsound driver.
        .module nullsound

        ;; defines and macros
        .include "nullsound.def"

        ;; user-defined: driver configuration, jump table
        ;; this file is provided by the user to build the sound driver
        .include "user_commands.def"



;;; --------------------------------------------------------------------------------
;;; Main ROM entry point
;;; --------------------------------------------------------------------------------
;;;
        .area START (ABS)
        di
        jp      init_z80_and_wait


;;; Restart handlers. An custom jump-table to the most called functions
;;; in this Z80 ROM. Accessed with the `RST` opcode, which is slightly
;;; faster and space-efficient than a regular `CALL` opcode.
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
        .org    0x0038
        di
        ;; TODO
        ei
        reti

;;; NMI handler (fixed address 0x0066 in the Z80)
        .org    0x0066
        ;; common driver commands
        ex      af, af'
        in      a, (PORT_FROM_68K)
        cp      #1
        jp      z, snd_command_01_prepare_for_rom_switch
        cp      #3
        jp      z, snd_command_03_reset_driver
        ;; else register the commands for later processing
        jp      snd_push_pending_request
_end_nmi::
        ex      af, af'
        retn


_rom_info:
        nullsound_id


        ;; the rest of the code is relative, to allow linking objects
        ;; set the location counter arbitrary far to not overwrite START
        .area CODE
        . = . + 0x0100

;;; the jump table to a sound command requested via NMI
;;; each entry is "jp <address>" (3 bytes)
;;; max 128 entries allowed in the sound driver
cmd_jmptable:
        ;; common/reserved sound commands
        jp      snd_command_nop
        jp      snd_command_01_prepare_for_rom_switch
        jp      snd_command_nop
        jp      snd_command_03_reset_driver
        ;; macro that inlines the user part of the jump table
        user_jmptable
cmd_jmptable_padding:
        ;; fill remaining commands if any
        .rept   128-((cmd_jmptable_padding - cmd_jmptable)/3)
        jp      snd_command_nop
        .endm


;;; Implementation of the common sound commands
;;;
        ;; Common YM2610 defines and functions
        .include "ym2610.def"
        .include "ym2610.s"


;;; This performs a very minimal Z80 initialization to quickly
;;; mute the ym2610 and to stay idle in RAM until the 68k sets up
;;; the proper Z80 ROM and triggers the sound driver initialization

init_z80_and_wait:
        ;; Configure the Z80 for interrupt mode 1 (fixed handler @ 0x0038)
        im      1
        ;; On the platform, the Z80 only receives NMIs once the Z80 ports
        ;; mapped to bankswitching have been written to.
        xor     a
        out     (PORT_ENABLE_NMI), a
        ;; Mute sound
        call snd_reset_ym2610
        ;; At this point, prepare to stay idle in RAM. This allows multi-slot
        ;; MVS cabinets to switch game and map the game's sound ROM in the
        ;; Z80 address space.
        prepare_wait_in_ram_opcodes
        ;; Returns to RAM and busy-loop until a NMI is triggered and resumes
        ;; the driver's initialization
        ret




        ;; Reserved commands (to init/reset the driver)
        .include "nullsound_commands.s"



;;; nullsound's mainloop
;;; --------------------
;;; This is a cooperative-scheduling event loop:
;;;  . it calls all the modules that are currently in use (playing sfx, playing music...)
;;;  . every module runs an initial init command to set up its state, it is only
;;;    run once thanks to self-modifying code in the init command
;;;
driver_init:
        ;; reset the ym2610
        call    snd_reset_ym2610
        ;; reset the pending command buffer
        xor     a
        ld      (snd_requests_current_offset), a
        ld      (snd_requests_pending_offset), a
        ;; reset the mainloop state in memory
        ld      hl, #rodata_modules
        ld      de, #modules
        ld      bc, #(modules_end - modules)
        ldir
mainloop:
        ld      hl, #modules
_mainloop:
        ;; check whether there are pending commands to process
        call    snd_process_pending_requests

        ;; parse the current module
        ;; ix <- (hl) command's state
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        push    de
        pop     ix

        ;; check if command is in use
        bit     7, d
        jr      z, _next_command

        ;; if so, call the action's command (dynamic call, with push+ret)
        ld      de, #_command_return
        push    de
        push    hl
        ret
_command_return:
        ;; update the state of the module if command finished execution
        cp      #ACTION_FINISHED
        jr      nz, _next_command
        dec     hl
        ld      (hl), #0
        inc     hl
_next_command:
        ;; loop to the next module
        ;; when the sentinel module is reached, it reset hl to the first module
        ld      bc, #(MODULE_SIZE-2)
        add     hl, bc
        jr      _mainloop


;;; The initial state of the module list is copied in RAM at startup/reset
;;; (see the module state section for more details)
rodata_modules:
        .rept   MODULES
        .ds     MODULE_SIZE
        .endm
        ;; this sentinel module resets the module pointer in the mainloop
        .dw     0xffff
        ld      hl, #(modules - MODULE_SIZE + 2)  ; reset module pointer
        ld      a, #1                                   ; this module is always in use
        ret
        nop


;;;
;;; The linker will add the user commands past this point in the ROM
;;;




;;; --------------------------------------------------------------------------------
;;; RAM and memory state
;;; some variables are initialized in RAM at startup/reset
;;; --------------------------------------------------------------------------------
;;;
        .area  DATA (ABS)
        .org    0xf800


;;; The ring buffer of the pending sound requests
;;; power of 2, max 128 bytes, must be aligned in memory so that the
;;; entire buffer fits in a single MSB address
snd_requests:
        .ds     MAX_PENDING_REQUESTS
;;; offset of the last processed command in the ring buffer
snd_requests_current_offset:
        .db     0
;;; all the offsets past current_offset up to pending_offset
;;; are sound requests to be processed
snd_requests_pending_offset:
        .db     0


;;; nullsound modules
;;; -----------------
;;; A module is a unit of sound that can run a sound action: play music, play
;;; ADPCM sample, play FM or SSG...
;;; A nullsound driver can be compiled to run various modules concurrently.
;;; For example, you could build a driver with 4 modules, where:
;;;   . one module is used to play your game's music
;;;   . two modules to play two ADPCM samples in parallel
;;;   . one module to play FM SFX (e.g. "insert coin" sound)
;;;
;;; A module has a state in RAM:
;;;   . if it is in use, a pointer to the sound action's state in RAM
;;;   . if a new action must start, a pointer to its init function in ROM
;;;   . a pointer to the current action function in ROM
;;;
;;; both the init and the current function are stored in a jump table.
;;;
;;;     .dw     0      ; action's internal state in memory
;;;     call    0      ; calls action's init function if needed
;;;     jp      0      ; jmp to action. the action yields to the mainloop


modules::
        .rept   MODULES
        .ds     MODULE_SIZE
        .endm
module_last:
        ;; sentinel
        .ds     MODULE_SIZE
modules_end:



;;; action state per module
;;; -----------------------
;;; A module can run different types of action (ADPCMA, ADPCMB, SSG...)
;;; and each action requires a specific amount of memory to keep track
;;; of its state.
;;; The module reserves enough memory to hold the largest possible state

module_states::
        .rept   MODULES
        .ds     ACTION_STATE_SIZE
        .endm
