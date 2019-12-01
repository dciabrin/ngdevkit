#!/usr/bin/env python3
# Copyright (c) 2015-2019 Damien Ciabrini
# This file is part of ngdevkit
#
# ngdevkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# ngdevkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

"""Generate a zoom ROM for nullbios, an open source BIOS for Neo Geo."""

import argparse

def write_zoom_level(zoom, out):
    """Write a zoom level to a file descriptor."""
    level = bytearray([255] * 256)
    for i, v in enumerate(filter(lambda x: x != None, zoom)):
        level[i] = v
    out.write(level)


def write_zoom_lookup_table(out):
    """Pre-compute a zoom lookup table and save it to a file.

    The zoom is a linear scaling of a block of 256 pixels. There are
    256 levels of zoom, where level n contains the n pixels to render."""
    for _ in range(2):
        zoom = [None]*256
        for i in (8, 12, 10, 14, 9, 13, 11, 15):
            for j in (0, 16, -8, 8):
                for k in (0, -128, 64, -64, 32, -96, 96, -32):
                    offset = 128 + i + j + k
                    zoom[offset] = offset
                    write_zoom_level(zoom, out)


def main():
    parser=argparse.ArgumentParser(
        description='Generate the Neo Geo zoom lookup table.')
    parser.add_argument('-o', '--output', type=argparse.FileType('wb'),
                        help='name of generated ROM')
    args = parser.parse_args()
    outf = args.output if args.output else open("000-lo.lo","wb")

    write_zoom_lookup_table(outf)


if __name__ == '__main__':
    main()
