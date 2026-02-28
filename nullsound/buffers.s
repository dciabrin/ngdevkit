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

;;; precalc buffers, addresses aligned to speed up 16-bit indexing
;;;

        .module nullsound

        .include "fm-tables.inc"
        .include "ssg-tables.inc"

        .area  CODE

        .bndry  256


;;; Convert note flat representation to <octave,semitone> representation
;;; ------
;;; Precalc for 8 octaves
        .bndry  128
note_to_octave_semitone::
        .db     0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b
        .db     0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b
        .db     0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b
        .db     0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b
        .db     0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b
        .db     0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b
        .db     0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b
        .db     0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b


;;; fixed-point sine precalc
;;; ------
;;; a 64 entries (128bytes) signed fixed point precalc of sin(x) for x in [0..2*pi],
;;; encoded as [-1.0..1.0] as [s..iffffffff....]. This serves as a base increment
;;; for vibrato displacement from 1..16, which yields a 9bits fixed point for
;;; displacement of the current NSS note
        .bndry  128
sine::
        .dw     0x0000, 0x0190, 0x0310, 0x04a0, 0x0610, 0x0780, 0x08e0, 0x0a20
        .dw     0x0b50, 0x0c50, 0x0d40, 0x0e10, 0x0ec0, 0x0f40, 0x0fb0, 0x0fe0
        .dw     0x1000, 0x0fe0, 0x0fb0, 0x0f40, 0x0ec0, 0x0e10, 0x0d40, 0x0c50
        .dw     0x0b50, 0x0a20, 0x08e0, 0x0780, 0x0610, 0x04a0, 0x0310, 0x0190
        .dw     0x8000, 0x8190, 0x8310, 0x84a0, 0x8610, 0x8780, 0x88e0, 0x8a20
        .dw     0x8b50, 0x8c50, 0x8d40, 0x8e10, 0x8ec0, 0x8f40, 0x8fb0, 0x8fe0
        .dw     0x9000, 0x8fe0, 0x8fb0, 0x8f40, 0x8ec0, 0x8e10, 0x8d40, 0x8c50
        .dw     0x8b50, 0x8a20, 0x88e0, 0x8780, 0x8610, 0x84a0, 0x8310, 0x8190


;;; Delta factor for all possible fractional semitones
;;; ------
;;; Internally nullsound works with decimal semitones (8:7 fixed point) to encode
;;; the tune shift of a note after FX (e.g. pitch, vibrato, slide...)
;;; There are 128 possible fractional semitones between two integer semitones.
;;;
;;; The frequency F (in Hz) of a decimal semitone s is given as:
;;;          F(s) = 440 * 2^(s/12)
;;;
;;; From there, we can derive the value to use for configuring SSG or FM as:
;;;        SSG(s) = s_factor / F(s)
;;;         FM(s) = f_factor * F(s)
;;; but this values can also be expressed as a position (a 'delta') between the
;;; values of the two closest integer semitones, with delta in [0..1[
;;;
;;; The value associated to a decimal semitone is _not_ a linear interpolation
;;; between the value of the closest integer semitones, however the delta of
;;; a decimal semitone is the same for all subsequent integer semitones, so
;;; we can use that precomputed delta to output a precise YM2610 value for
;;; every decimal semitone.

;;; SSG tune delta for all 128 fractional semitones
ssg_tune_deltas::
        .ssg_tune_deltas_data

;;; FM F-num delta for all 128 fractional semitones
fm_fnum_deltas::
        .fm_fnum_deltas_data


;;; Semitone frequency table
;;; ------
;;; For SSG channels, a note is encoded in the YM2610 as a 12bit value
;;; inversely proportional to the note's frequency in Hz:
;;;         note_ym2610 = (8M/64)/note_frequency
;;; In order to encode all frequencies faithfully (8*12 semitones * 128 shifts),
;;; nullsound represents a note by a 24bit value (12:12 fixed point) and relies
;;; on note distances (24bits) and a delta table (16bits) to compute the final
;;; 12bit integer value for the YM2610.

;;; SSG tune table for AES masterclock (8M=8055943)
        .bndry 256
ssg_dists_lsb::
        .ssg_dists_lsb_data

        .bndry 256
ssg_tunes_msb::
        .ssg_dists_msb_data

        .bndry 128
ssg_tunes_lsb::
        .ssg_tunes_lsb_data

        .bndry 128
ssg_dists_msb::
        .ssg_dists_lsb_data


;;; F-num frequency table
;;; ------
;;; A note can be seen as a tuple <octave,semitone>. Likewise, its frequency F in Hz
;;; can be decomposed as a F(note) = 2^octave * F(semitone)
;;; Likewise, FM channels encode a note as a 14bits tuple `block * F-num`, where:
;;; block (3bits) is the octave and F-num (11bits) is a factor of the semitone's
;;; frequency for the first octave.
;;;         F-num = ((144*2^20)/8M) * semitone_frequency
;;;         block = 2^(octave-1)
;;; With this representation, we just need 12 precomputed entries to represent
;;; acurately the frequency of all semitones for all octaves.
;;; In order to encode all frequencies faithfully (12 semitones * 128 shifts),
;;; nullsound represents a F-num by a 23bit value (11:12 fixed point) and relies
;;; on note distances (23bits) and a delta table (16bits) to compute the final
;;; 11bit F-num value for the YM2610.

;;; FM F-num table for AES masterclock (8M=8055943)
fm_fnums::
        .fm_fnums_data

fm_dists::
        .fm_dists_data
