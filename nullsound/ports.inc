;;; -*- asm -*-
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

;;; The following macros are based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=Z80_port_map


;;; Z80 ports mapped to the YM2610
        ;; read ports
        .equ    PORT_FROM_68K,               0x00
        .equ    PORT_YM2610_STATUS,          0x04
        .equ    PORT_PLAYBACK_FINISHED,      0x06
        ;; write ports
        .equ    PORT_YM2610_A_ADDR,          0x04
        .equ    PORT_YM2610_A_VALUE,         0x05
        .equ    PORT_YM2610_B_ADDR,          0x06
        .equ    PORT_YM2610_B_VALUE,         0x07
        .equ    PORT_ENABLE_NMI,             0x08
        .equ    PORT_TO_68K,                 0x0c
        .equ    PORT_DISABLE_NMI,            0x18
