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


;;; Semitone frequency table
;;; ------
;;; A note in nullsound is represented as a tuple <octave, semitone>,
;;; which is translated into YM2610's register representation
;;; 250000/`coarse|fine` Hz, where coarse|fine is a 4|8bits divider.
;;; This table precomputes the dividers for C1 up to B8
;;; 8 octaves * 12 semitones (padded to 16 entries)
;;; 128 entries * 12 bits (2 bytes) = 256 bytes
;;; When aligned, this is quick to address for the Z80
        .bndry  256
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

