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

        ;; Those constants ensure that the entire state of a sound channel
        ;; never crosses a single 256 bytes boundary, which eases additions
        ;; and indexing.
        ;; the .bndry statement is only local to a single file, i.e. it is
        ;; only enforced by the assembler, not by the linker. So we have
        ;; to tune the constants below to achieve our desired alignment.

        .lclequ ALIGN_OFFSET_FM,        0xbc
        .lclequ ALIGN_OFFSET_SSG,       0x50
        .lclequ ALIGN_OFFSET_ADPCM_A,   0x52
        .lclequ ALIGN_OFFSET_ADPCM_B,   0x1a
