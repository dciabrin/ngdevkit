;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2020-2025 Damien Ciabrini
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

;;; The following is based on doc found on neogeodev wiki
;;; https://wiki.neogeodev.org/index.php?title=Z80

        .module nullsound

        .include "ports.inc"
        .include "ym2610.inc"


        .area CODE


;;; bank configuration for a flat 64KB ROM access
bank_64k_linear::
        .db     0x1e, 0x0e, 0x06, 0x02


;;; Reconfigure the ROM window accessed from address 0x8000..0xf7ff
;;; ------
;;;   [ bc ] window 0 : (val * 0x0800) 0xf000..0xf7ff
;;;   [bc+1] window 1 : (val * 0x1000) 0xe000..0xefff
;;;   [bc+2] window 2 : (val * 0x2000) 0xc000..0xdfff
;;;   [bc+3] window 3 : (val * 0x4000) 0x8000..0xbfff
;;; [bc modified]
bank_switch::
        ld      a, (bc)
        in      a, (PORT_BANK_WINDOW_0)
        inc     bc
        ld      a, (bc)
        in      a, (PORT_BANK_WINDOW_1)
        inc     bc
        ld      a, (bc)
        in      a, (PORT_BANK_WINDOW_2)
        inc     bc
        ld      a, (bc)
        in      a, (PORT_BANK_WINDOW_3)
        ret
