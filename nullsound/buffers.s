;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024 Damien Ciabrini
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

        .area  CODE

        .bndry  256

;;; Semitone frequency table
;;; ------
;;; A note in nullsound is represented as a tuple <octave, semitone>,
;;; which is translated into YM2610's register representation
;;; 250000/`coarse|fine` Hz, where coarse|fine is a 4|8bits divider.
;;; This table precomputes the dividers for C1 up to B8
;;; 8 octaves * 12 semitones (padded to 16 entries)
;;; 128 entries * 12 bits (2 bytes) = 256 bytes
;;; When aligned, this is quick to address for the Z80
ssg_tune::
        ;;         C-n,    C#n,    D-n,    D#n,    E-n,    F-n,    F#n,    G-n,    G#n,    A-n,    A#n,    B-n
        .dw     0x1ddd, 0x1c2f, 0x1a9a, 0x191c, 0x17b3, 0x165f, 0x151d, 0x13ee, 0x12d0, 0x11c1, 0x10c2, 0x0fd1, 0, 0, 0, 0
        .dw     0x0eee, 0x0e17, 0x0d4d, 0x0c8e, 0x0bd9, 0x0b2f, 0x0a8e, 0x09f7, 0x0968, 0x08e0, 0x0861, 0x07e8, 0, 0, 0, 0
        .dw     0x0777, 0x070b, 0x06a6, 0x0646, 0x05ec, 0x0597, 0x0547, 0x04fb, 0x04b3, 0x0470, 0x0430, 0x03f4, 0, 0, 0, 0
        .dw     0x03bb, 0x0385, 0x0353, 0x0323, 0x02f6, 0x02cb, 0x02a3, 0x027d, 0x0259, 0x0238, 0x0218, 0x01fa, 0, 0, 0, 0
        .dw     0x01dd, 0x01c2, 0x01a9, 0x0191, 0x017b, 0x0165, 0x0151, 0x013e, 0x012c, 0x011c, 0x010c, 0x00fd, 0, 0, 0, 0
        .dw     0x00ee, 0x00e1, 0x00d4, 0x00c8, 0x00bd, 0x00b2, 0x00a8, 0x009f, 0x0096, 0x008e, 0x0086, 0x007e, 0, 0, 0, 0
        .dw     0x0077, 0x0070, 0x006a, 0x0064, 0x005e, 0x0059, 0x0054, 0x004f, 0x004b, 0x0047, 0x0043, 0x003f, 0, 0, 0, 0
        .dw     0x003b, 0x0038, 0x0035, 0x0032, 0x002f, 0x002c, 0x002a, 0x0027, 0x0025, 0x0023, 0x0021, 0x001f, 0, 0, 0, 0

;;; Vibrato - Semitone distance table
;;; ------
;;; each element in the table holds the distance to the previous semitone
;;; in the note table. The vibrato effect oscillate between one semi-tone
;;; up and down of the current note of the SSG channel.
ssg_semitone_distance::
        ;;       C-n,  C#n,  D-n,  D#n,  E-n,  F-n,  F#n,  G-n,  G#n,  A-n,  A#n,  B-n, C-(n+1)
        .db     0xe3, 0xd7, 0xca, 0xbf, 0xb5, 0xaa, 0xa1, 0x97, 0x8f, 0x88, 0x7f, 0x79, 0x71, 0, 0, 0
        .db     0xe3, 0xd7, 0xca, 0xbf, 0xb5, 0xaa, 0xa1, 0x97, 0x8f, 0x88, 0x7f, 0x79, 0x71, 0, 0, 0
        .db     0x71, 0x6c, 0x65, 0x60, 0x5a, 0x55, 0x50, 0x4c, 0x48, 0x43, 0x40, 0x3c, 0x39, 0, 0, 0
        .db     0x39, 0x36, 0x32, 0x30, 0x2d, 0x2b, 0x28, 0x26, 0x24, 0x21, 0x20, 0x1e, 0x1d, 0, 0, 0
        .db     0x1d, 0x1b, 0x19, 0x18, 0x16, 0x16, 0x14, 0x13, 0x12, 0x10, 0x10, 0x0f, 0x0f, 0, 0, 0
        .db     0x0f, 0x0d, 0x0d, 0x0c, 0x0b, 0x0b, 0x0a, 0x09, 0x09, 0x08, 0x08, 0x08, 0x07, 0, 0, 0
        .db     0x07, 0x07, 0x06, 0x06, 0x06, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x04, 0x04, 0, 0, 0
        .db     0x04, 0x03, 0x03, 0x03, 0x03, 0x03, 0x02, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0, 0, 0

;;; Sine precalc
;;; ------
;;; a 64 bytes 2*Pi sign precalc encoded as  3-bit magnitude + 1-bit sign
;;; This is used by the vibrato effect
sine::
        .db      0,  0,  9, 10, 11, 11, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15
        .db     15, 15, 15, 15, 15, 15, 14, 14, 13, 13, 12, 11, 11, 10,  9,  0
        .db      0,  0,  1,  2,  3,  3,  4,  5,  5,  6,  6,  7,  7,  7,  7,  7
        .db      7,  7,  7,  7,  7,  7,  6,  6,  5,  5,  4,  3,  3,  2,  1,  0
