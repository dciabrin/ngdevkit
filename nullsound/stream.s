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


;;;
;;; Sound stream state tracker
;;; -------------------
;;;  . next sound opcode to be processed from the stream
;;;  . current volume per channel type (FM, ADPCM...)
;;;  . current detune per channel type (FM, ADPCM...)
;;;
        .area  DATA

state_stream_in_use::
        .db     0x00

state_stream_current_addr::
        .dw     0x00

state_stream_instruments::
        .dw     0x00


        .area  CODE

init_stream_state_tracker::
        ld      a, #0
        ld      (state_stream_in_use), a
        ld      bc, #0
        ld      (state_stream_current_addr), bc
        ld      (state_stream_instruments), bc
        ret


;;; Evaluate the opcodes from the current nullsound stream,
;;; until an opcode must yield the execution (end of stream, timer wait)
;;; the current stream and current opcode pointer are in memory
;;; ------
;;; [a modified - other registers saved]
update_stream_state_tracker::
        push    hl
        push    bc
        ;; check whether stream is in use
        ld      a, (state_stream_in_use)
        or      a
        jp      z, _no_more_processing
        ;; check whether we can process the next nss opcodes
        ld      a, (state_timer_int_b_wait)
        ld      b, a
        ld      a, (state_timer_int_b_count)
        cp      b
        jp      c, _no_more_processing
        sub     b
        ld      (state_timer_int_b_count), a
process_opcodes::
        push    ix
        ;; process the next opcodes
        ld      hl, (state_stream_current_addr)
_loop_opcode:
        call    process_nss_opcode
        or      a
        jp      nz, _loop_opcode
        ;; no more opcodes can be processed
        ld      (state_stream_current_addr), hl
        pop     ix
_no_more_processing:
        pop     bc
        pop     hl
        ret


;;; Play music or sfx from a pre-compiled stream of sound opcodes
;;; the data is encoded in the nullsound stream format
;;; ------
;;; bc: nullsound stream to play
;;; [a modified - other registers saved]
snd_stream_play::
        call    snd_stream_stop
        ld      (state_stream_current_addr), de
        ld      (state_stream_instruments), bc
        ld      a, #1
        ld      (state_stream_in_use), a
        ;; start stream playback, it will get preempted
        ;; as soon as a wait opcode shows up in the stream
        call    update_stream_state_tracker
        ret


;;; Stop music or sfx stream playback
;;; ------
;;; [a modified - other registers saved]
snd_stream_stop::
        call    ym2610_reset

        ld      a, #0
        ld      (state_stream_in_use), a
        ld      (state_timer_int_b_count), a
        ld      (state_timer_int_b_wait), a
        ret


;;; NSS opcodes lookup table
;;; ------
;;; The functions below all follow the same interface
;;; bc [IN]: arguments of the current NSS opcode in the stream
;;;          bc gets incremented to all the parse arguments, and
;;;          on function exit, bc must point to the next NSS opcode
;;;          in the stream
;;; a [OUT]: 1: processing of the next opcode can continue
;;;          0: processing must stop (the playback must wait for
;;;             the timer for sync, or the stream is finished)
;;;
;;; [a and bc modified - other registers must be saved]
nss_opcodes:
        .dw     write_port_a
        .dw     write_port_b
        .dw     0
        .dw     finish
        .dw     run_timer_b
        .dw     wait_int_b
        .dw     fm_instrument
        .dw     fm_note_on
        .dw     fm_note_off
        .dw     adpcm_a_instrument
        .dw     adpcm_a_on
        .dw     adpcm_a_off
        .dw     adpcm_b_instrument
        .dw     adpcm_b_note_on


;;; Process a single NSS opcode
;;; ------
;;; bc: address in the stream pointing to the opcode and its args
;;; [a, bc, ix modified - other registers saved]
process_nss_opcode::
        ;; op
        ld      a, (hl)
        inc     hl
        ;; get function for opcode and tail call into it
        ld      ix, #nss_opcodes
        sla     a
        ld      b, #0
        ld      c, a
        add     ix, bc
        ld      b, 1(ix)
        ld      c, (ix)
        push    bc
        ret


;;;
;;; NSS opcodes
;;;

;;; WRITE_PORT_A
;;; generic write to YM2610 register reacheable from port A
;;; ------
;;; [ hl ]: register
;;; [hl+1]: value
write_port_a::
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a
        ld      a, #1
        ret


;;; WRITE_PORT_B
;;; generic write to YM2610 register reacheable from port B
;;; ------
;;; [ hl ]: register
;;; [hl+1]: value
write_port_b::
        ld      b, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_b
        ld      a, #1
        ret


;;; FINISH
;;; signal the end of the NSS stream to the player
;;; ------
finish::
        xor     a
        ld      (state_stream_in_use), a
        ld      a, #0
        ret


;;; RUN_TIMER_B
;;; configure YM2610's timer B and start it
;;; ------
;;; [hl]: Timer B counter
run_timer_b::
        ;; reset all timers
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x30
        call    ym2610_write_port_a
        ;; configure timer B
        ld      b, #REG_TIMER_B_COUNTER
        ld      c, (hl)
        inc     hl
        call    ym2610_write_port_a
        ;; deconfigure timer A (TODO remove it)
        ld      b, #REG_TIMER_A_COUNTER_LSB
        ld      c, #0x0
        call    ym2610_write_port_a
        ld      b, #REG_TIMER_A_COUNTER_MSB
        ld      c, #0x0
        call    ym2610_write_port_a
        ;; start timer right away
        ld      a, #0
        ld      (state_timer_int_b_count), a
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x3A
        call    ym2610_write_port_a
        ei
        ld      a, #1
        ret


;;; WAIT_INT_B
;;; Suspend stream playback, resume after a number of Timer B
;;; interrupts has passed.
;;; ------
;;; [hl]: number of interrupts unti lplayback resumes
wait_int_b::
        ;;  how many interrupts to wait for before moving on
        ld      a, (hl)
        inc     hl
        ld      (state_timer_int_b_wait), a
        ld      a, #0
        ret
