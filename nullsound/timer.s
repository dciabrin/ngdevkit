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


        .area  CODE

init_timer_state_tracker::
        ld      a, #0
        ld      (state_timer_int_a_count), a
        ld      (state_timer_int_a_wait), a
        ld      (state_timer_int_b_count), a
        ld      (state_timer_int_b_wait), a
        ret


update_timer_state_tracker::
        ;; keep track of the new interrupt
        ld      a, (state_timer_int_b_count)
        inc     a
        ld      (state_timer_int_b_count), a
        ;; reset and rearm the ym2610 timer
        ld      b, #REG_TIMER_FLAGS
        ld      c, #0x3a
        call    ym2610_write_port_a
        ret
