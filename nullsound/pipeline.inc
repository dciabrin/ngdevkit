;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024-2025 Damien Ciabrini
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

;;; Common macros for FM, SSG, ADPCM-A and ADPCM-B FX pipelines
;;;


        ;; pipeline state for channels
        .lclequ STATE_PLAYING,          0x01
        .lclequ STATE_EVAL_MACRO,       0x02
        .lclequ STATE_LOAD_NOTE,        0x04
        .lclequ STATE_LOAD_WAVEFORM,    0x08
        .lclequ STATE_LOAD_VOL,         0x10
        .lclequ STATE_LOAD_REGS,        0x20
        .lclequ STATE_STOP_NOTE,        0x40
        .lclequ STATE_NOTE_STARTED,     0x80

        .lclequ BIT_PLAYING,            0
        .lclequ BIT_EVAL_MACRO,         1
        .lclequ BIT_LOAD_NOTE,          2
        .lclequ BIT_LOAD_WAVEFORM,      3
        .lclequ BIT_LOAD_VOL,           4
        .lclequ BIT_LOAD_REGS,          5
        .lclequ BIT_STOP_NOTE,          6
        .lclequ BIT_NOTE_STARTED,       7
