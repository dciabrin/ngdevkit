;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2025 Damien Ciabrini
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

;;; Constants for linking data with desired RAM alignment
;;;

        ;; These macros ensure that the data between two .align_start
        ;; and .align_end macro calls stick in a single 256 bytes
        ;; boundary, to make 16bit arithmetic faster.

        .macro  .align_begin sym
        _'sym'_align: .blkb _padding_'sym
        _'sym'_begin:
        .endm

        .macro  .align_end sym
        _'sym'_end:
        .endm

        ;; Those constants tweak the alignment of symbols in RAM to match
        ;; our 256bytes boundaries constraints.

        .lclequ _padding_state_timer,   0x0
        .lclequ _padding_state_fm1,     0xb5
        .lclequ _padding_state_fm2,     0xc6
        .lclequ _padding_state_fm3,     0x26
        .lclequ _padding_state_fm4,     0x0
        .lclequ _padding_state_ssg,     0x8c
        .lclequ _padding_state_adpcm,   0x48
        .lclequ _padding_state_adpcm_b, 0xc0
