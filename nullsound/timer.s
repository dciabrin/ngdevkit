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
;;; Timer state tracker
;;; -------------------
;;;  Keep track of interrupts triggered by the YM2610, used by
;;;  the stream player as a reliable time source for synchronization.
;;;
        .area  DATA

state_timer_int_a_count::
        .db     0

state_timer_int_a_wait::
        .db     0

state_timer_int_b_count::
        .db     0

state_timer_int_b_wait::
        .db     0

state_timer_int_b_reached::
        .db     0

        .area  CODE

init_timer_state_tracker::
        ld      a, #0
        ld      (state_timer_int_a_count), a
        ld      (state_timer_int_a_wait), a
        ld      (state_timer_int_b_count), a
        ld      (state_timer_int_b_wait), a
        ld      (state_timer_int_b_reached), a
        ret


update_timer_state_tracker::
        ld      a, #1
        ld      (state_timer_int_b_reached), a
        ;; keep track of the new interrupt
        ld      a, (state_timer_int_b_count)
        inc     a
        ld      (state_timer_int_b_count), a

        ;; update the YM2610 here to reset the interrupt flags
        ;; and rearm the interrupt timer
        ;; NOTE: in doing so we might actually be stealing the
        ;; ym2610 register context from a ongoing ym2610_write_port_a.
        ;; so we have to update the YM2610 with care

        ;; step1: wait before reading/writing anything, so that
        ;; if we interrupted a ym2610_write_port_a, it gets a chance to
        ;; update the YM2610 properly
        call    ym2610_wait_available

        ;; reset interrupt timer B
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x2a
        call    ym2610_write_port_a

        ;; step2: at this stage, if we interrupted a ym2610_write_port_a,
        ;; restore the YM2610 register context before returning from the
        ;; interrupt handler
        call    ym2610_restore_context_port_a

        ret
