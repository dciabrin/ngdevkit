#!/usr/bin/env python3
# Copyright (c) 2018-2026 Damien Ciabrini
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

"""paltool.py - Neo Geo graphics palette management

Extract palette from a 2D image and convert it to C or ASM data.
"""

import argparse

from PIL import Image
from itertools import batched

def rgb24_to_packed15(col):
    r, g, b = [c >> 2 for c in col]
    # heuristic: set the dark bit only when the
    # LSB of all components is null. Just follow
    # the same rule when you design your palette
    # for your sprites and tiles, for them to
    # match when converted for the Neo Geo.
    darkbit = 1 if ((r & 1) + (g & 1) + (b & 1)) == 0 else 0
    r, g, b = r >> 1, g >> 1, b >> 1
    lsb = ((r & 1) << 2) | ((g & 1) << 1) | (b & 1)
    r, g, b = r >> 1, g >> 1, b >> 1
    packed = darkbit << 15 | lsb << 12 | r << 8 | g << 4 | b
    return packed


def output_c_anonymous_palette(pal, outfile):
    print("{", ", ".join(["0x%04x"%c for c in pal]), "},", file=outfile)


def main():
    parser = argparse.ArgumentParser(
        description='Extract palette from a 2D image and convert it.')
    parser.add_argument('FILE', help='file to process')
    parser.add_argument('-o', '--output', metavar='OUTFILE', type=str,
                        required = True,
                        help='extracted 16-colours palette')

    arguments = parser.parse_args()

    img = Image.open(arguments.FILE)

    # extract the palette as a 24bits RGB
    pal_ints = img.getpalette()
    pal_rgb = list(batched(pal_ints, 3))
    # make sure the palette has 16colors
    if len(pal_rgb) > 16:
        pal_rgb = pal_rgb[:16]
    elif len(pal_rgb) < 16:
        pal_rgb.extend([(0, 0, 0)] * (16 - len(pal_rgb)))

    ngpal = [rgb24_to_packed15(c) for c in pal_rgb]

    out = open(arguments.output, "w")
    output_c_anonymous_palette(ngpal, out)


if __name__ == '__main__':
    main()
