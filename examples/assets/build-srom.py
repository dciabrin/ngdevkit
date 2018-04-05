#!/usr/bin/env python
# Copyright (c) 2018 Damien Ciabrini
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


import struct
import os
import sys
import argparse
from random import randint

import pygame

# Tiles position for the original boot text
# https://wiki.neogeodev.org/index.php?title=Eyecatcher

MAX_330_MEGA = (
  ( 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F, 0x15, 0x17, 0x19, 0x1B, 0x1D, 0x1F, 0x5E, 0x60, 0x7D ),
  ( 0x06, 0x08, 0x0A, 0x0C, 0x0E, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E, 0x40, 0x5F, 0x7C, 0x7E )
)
			
# Caveat: tile 0xff must be empty as it's used for clearing up
# the tile map. So choose the text message accordingly...
PRO_GEAR_SPEC = (
  ( 0x7F, 0x9A, 0x9C, 0x9E, 0xFF, 0xBB, 0xBD, 0xBF, 0xDA, 0xDC, 0xDE, 0xFA, 0xFC, 0x100, 0x102, 0x104, 0x106 ),
  ( 0x99, 0x9B, 0x9D, 0x9F, 0xBA, 0xBC, 0xBE, 0xD9, 0xDB, 0xDD, 0xDF, 0xFB, 0xFD, 0x101, 0x103, 0x105, 0x107 )
)


def blit_msg(dst, src, string, all_tiles):
    row=0
    for string_tiles in all_tiles:
        for letter, tile in zip(string, string_tiles):
            tile *= 8
            xpos = tile % 2048;
            ypos = (tile / 2048) * 8;
            dst.blit(src, (xpos, ypos), area = (ord(letter)*8, row, 8, 8))
        row+=8

        
def main():
    pygame.init()
    pygame.display.init()

    parser = argparse.ArgumentParser(
        description='Build common Fixed and Sprite ROMs for all examples.')
    parser.add_argument('-s', '--small', metavar = 'FILENAME', type = str,
                        required = True,
                        help = 'image for the small text tiles')
    parser.add_argument('-t', '--tall', metavar='FILENAME', type=str,
                        required = True,
                        help='image for the tall text tiles')
    parser.add_argument('-o', '--output', metavar='FILENAME', type=str,
                        required = True,
                        help='output image for fix-tile ROM file')

    arguments = parser.parse_args()
    
    # load the images and make sure they share the same palette
    # for the blit to keep pixel values intact
    dst = pygame.Surface((2048, 40), depth = 8)
    smalltxt = pygame.image.load(arguments.small)
    talltxt = pygame.image.load(arguments.tall)
    pal = smalltxt.get_palette()
    talltxt.set_palette(pal)
    dst.set_palette(pal)
    # Small and tall text tiles
    dst.blit(smalltxt, (0,0))
    dst.blit(talltxt, (0,8))
    dst.blit(talltxt, (0,24))
    # Inject a new message
    blit_msg(dst, talltxt, "16BITS POWERED ", MAX_330_MEGA)
    blit_msg(dst, talltxt, "GAME DEVELOPMENT", PRO_GEAR_SPEC)
    # Some tiles need to be empty no matter what
    dst.blit(dst, (ord('@')*8, 16), area = (0, 0, 8, 8)) 
    dst.blit(dst, (ord('{')*8, 0), area = (0, 0, 8, 8))
    dst.blit(dst, (0xff*8, 16), area = (0, 0, 8, 8))

    pygame.image.save(dst, arguments.output)


if __name__ == '__main__':
    main()
