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



;;; ym2610_set_register_ports_4_5
;;; -----------------------------
;;; IN:
;;;    b: register address in ym2610
;;;    c: data to set
;;; (all registers are preserved)
ym2610_set_register_ports_4_5::
        push    af
        ;; select address register
        ld      a, b
        out     (PORT_4_ADDR), a
_wait_address_ready_45:
        in      a, (PORT_YM2610_STATUS)
        bit     7, a
        jp      nz, _wait_address_ready_45
        ;; set data in the selected register
        ld      a, c
        out     (PORT_5_VALUE), a
_wait_data_ready_45:
        in      a, (PORT_YM2610_STATUS)
        bit     7, a
        jp      nz, _wait_data_ready_45
        pop     af
        ret


;;; ym2610_set_register_ports_6_7
;;; -----------------------------
;;; IN:
;;;    b: register address in ym2610
;;;    c: data to set
;;; (all registers are preserved)
ym2610_set_register_ports_6_7::
        push    af
        ;; select address register
        ld      a, b
        out     (PORT_6_ADDR), a
_wait_address_ready:
        in      a, (PORT_YM2610_STATUS)
        bit     7, a
        jp      nz, _wait_address_ready
        ;; set data in the selected register
        ld      a, c
        out     (PORT_7_VALUE), a
_wait_data_ready:
        in      a, (PORT_YM2610_STATUS)
        bit     7, a
        jp      nz, _wait_data_ready
        pop     af
        ret
