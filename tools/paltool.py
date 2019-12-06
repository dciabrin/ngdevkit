#!/usr/bin/env python3
# Copyright (c) 2018-2019 Damien Ciabrini
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

from __future__ import print_function
import struct
import os
import sys
import argparse
from random import randint

os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = '1'
os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['SDL_AUDIODRIVER'] = 'dummy'
import pygame


def rgb24_to_packed15(col):
    r, g, b = col
    lsb = (r&1 << 2) + (g&1 << 1) + b&1
    packed = lsb<<12 | (r>>4) << 8 | (g>>4) << 4 | (b>>4)
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

    img = pygame.image.load(arguments.FILE)

    # only keep the first 16 colors, even if palette has other
    # colors initialized but unused.
    pal = img.get_palette()[:16]

    # for the time being, do not the 16th bit available in
    # the Neo Geo hardware
    ngpal = [rgb24_to_packed15(c) for c in pal]

    out = open(arguments.output, "w")
    output_c_anonymous_palette(ngpal, out)


if __name__ == '__main__':
    main()
