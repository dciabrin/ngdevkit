#!/usr/bin/env python3
# Copyright (c) 2015-2026 Damien Ciabrini
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

import argparse
import os
import sys
from abc import abstractmethod
from random import randint
from typing import (
    BinaryIO,
    Generator,
    Iterator,
    List,
    Self,
)

from PIL import Image

#
# Encoding and decoding functions for all tile format (C-ROM, S-ROM, SPR)
#


# C-ROM
# A 16x16 sprite tile takes 16 * 16 * 4bits = 1024bits = 128bytes,
# split into two different ROMs (64bytes each). Data are organized
# into 4 8x8 blocks, stored as sequences of horizontal rows.
# Each row is encoded in 4 successive bitplanes of 8 bits
# over ROM c1 (plane 0; plane 1) and c2 (plane 2; plane 3).


def decode_crom_tile(crom1: bytes, crom2: bytes) -> bytes:
    """
    Extract the pixel data of a 16x16 tile encoded in two complementary C-ROMs,
    and convert them into a flat byte buffer (1-byte per pixel).
    """
    # 16x16 pixels output
    tile = bytearray(256)
    i1: Iterator[int] = iter(crom1)
    i2: Iterator[int] = iter(crom2)
    for tile8x8_offset in (8, 136, 0, 128):
        offset: int = tile8x8_offset

        for y in range(8):
            row_bitplane0 = next(i1)
            row_bitplane1 = next(i1)
            row_bitplane2 = next(i2)
            row_bitplane3 = next(i2)

            for x in range(8):
                bp1 = (row_bitplane0 >> x) & 1
                bp2 = (row_bitplane1 >> x) & 1
                bp3 = (row_bitplane2 >> x) & 1
                bp4 = (row_bitplane3 >> x) & 1
                col = (bp4 << 3) + (bp3 << 2) + (bp2 << 1) + bp1
                tile[offset] = col
                offset += 1
            offset += 8
    return bytes(tile)


def encode_crom_tile(tile: bytes) -> tuple[bytes, bytes]:
    """
    Convert the pixel data of a 16x16 tile (1-byte per pixel) into
    its equivalent C-ROM representation, split into two buffers
    """
    crom1 = bytearray(64)
    crom2 = bytearray(64)
    crom_pos = 0
    for tile8x8_start_offset in (8, 136, 0, 128):
        tile_offset: int = tile8x8_start_offset

        for y in range(8):
            row_bitplane0 = 0
            row_bitplane1 = 0
            row_bitplane2 = 0
            row_bitplane3 = 0

            for x in range(8):
                col = tile[tile_offset]
                row_bitplane0 += ((col >> 0) & 1) << x
                row_bitplane1 += ((col >> 1) & 1) << x
                row_bitplane2 += ((col >> 2) & 1) << x
                row_bitplane3 += ((col >> 3) & 1) << x
                tile_offset += 1

            crom1[crom_pos : crom_pos + 2] = (row_bitplane0, row_bitplane1)
            crom2[crom_pos : crom_pos + 2] = (row_bitplane2, row_bitplane3)
            crom_pos += 2
            tile_offset += 8
    return (bytes(crom1), bytes(crom2))


# SPR file
# A 16x16 sprite tile takes 16 * 16 * 4bits = 1024bits = 128bytes,
# stored contiguously in a file. Data are organized into 4
# 8x8 blocks, stored as sequences of horizontal rows.
# Each row is encoded in 4 successive bitplanes of 8 bits in
# a byte swapped order compared to C-ROM (planes, 1, 0, 3, 2).


def decode_spr_tile(spr: bytes) -> bytes:
    """
    Extract the pixel data of a 16x16 tile encoded in a SPR file format,
    and convert them into a flat byte buffer (1-byte per pixel).
    """
    tile = bytearray(256)
    i: Iterator[int] = iter(spr)
    for tile8x8_offset in (8, 136, 0, 128):
        offset: int = tile8x8_offset

        for y in range(8):
            row_bitplane1 = next(i)
            row_bitplane0 = next(i)
            row_bitplane3 = next(i)
            row_bitplane2 = next(i)

            for x in range(8):
                bp1 = (row_bitplane0 >> x) & 1
                bp2 = (row_bitplane1 >> x) & 1
                bp3 = (row_bitplane2 >> x) & 1
                bp4 = (row_bitplane3 >> x) & 1
                col = (bp4 << 3) + (bp3 << 2) + (bp2 << 1) + bp1
                tile[offset] = col
                offset += 1
            offset += 8
    return bytes(tile)


def encode_spr_tile(tile: bytes) -> bytes:
    """
    Convert the pixel data of a 16x16 tile (1-byte per pixel) into
    its equivalent SPR file representation.
    """
    spr = bytearray(128)
    pos = 0
    for tile8x8_offset in (8, 136, 0, 128):
        offset = tile8x8_offset

        for y in range(8):
            row_bitplane0 = 0
            row_bitplane1 = 0
            row_bitplane2 = 0
            row_bitplane3 = 0

            for x in range(8):
                col = tile[offset]
                row_bitplane0 += ((col >> 0) & 1) << x
                row_bitplane1 += ((col >> 1) & 1) << x
                row_bitplane2 += ((col >> 2) & 1) << x
                row_bitplane3 += ((col >> 3) & 1) << x
                offset += 1

            spr[pos : pos + 4] = (
                row_bitplane1,
                row_bitplane0,
                row_bitplane3,
                row_bitplane2,
            )
            pos += 4
            offset += 8
    return bytes(spr)


# S-ROM
# A 8x8 fixed layer tile takes 8 * 8 * 4bits = 256bits = 32bytes,
# The pixel data is encoded as 8 horizontal lines of 8 pixels
# (4 bytes each), where each horizontal line encodes pixel
# on byte swapped order: pixel 4, 5, 6, 7, 0, 1, 2, 3.


def decode_srom_tile(srom: bytes) -> bytes:
    """
    Extract the pixel data of a 8x8 tile encoded in a S-ROM,
    and convert them into a flat byte buffer (1-byte per pixel).
    """
    # 8x8 pixels output
    tile = bytearray(64)
    i: Iterator[int] = iter(srom)
    for xa, xb in ((4, 5), (6, 7), (0, 1), (2, 3)):
        for y in range(8):
            two_pixels = next(i)
            pixel_a = two_pixels & 0xF
            pixel_b = (two_pixels >> 0x4) & 0xF
            tile[(8 * y) + xa] = pixel_a
            tile[(8 * y) + xb] = pixel_b
    return bytes(tile)


def encode_srom_tile(srom: bytes) -> bytes:
    """
    Convert the pixel data of a 8x8 tile (1-byte per pixel) into
    its equivalent S-ROM representation.
    """
    # 8x8 pixels output
    tile = bytearray(32)
    i = 0
    for xa, xb in ((4, 5), (6, 7), (0, 1), (2, 3)):
        for y in range(8):
            pixel_a = srom[(8 * y) + xa]
            pixel_b = srom[(8 * y) + xb] << 4
            tile[i] = pixel_b | pixel_a
            i += 1
    return bytes(tile)


#
# Higher-level encoding and decoding functions, with PIL parameters
#


def crom_tile_to_image(crom1: bytes, crom2: bytes) -> Image.Image:
    """PIL wrapper to decode_crom_tile"""
    data = decode_crom_tile(crom1, crom2)
    return Image.frombytes("P", (16, 16), data)


def image_to_crom_tile(tile: Image.Image) -> tuple[bytes, bytes]:
    """PIL wrapper to encode_crom_tile"""
    data = tile.tobytes()
    return encode_crom_tile(data)


def srom_tile_to_image(srom: bytes) -> Image.Image:
    """PIL wrapper to decode_srom_tile"""
    data = decode_srom_tile(srom)
    return Image.frombytes("P", (8, 8), data)


def image_to_srom_tile(tile: Image.Image) -> bytes:
    """PIL wrapper to encode_srom_tile"""
    data = tile.tobytes()
    return encode_srom_tile(data)


def sprfile_tile_to_image(spr: bytes) -> Image.Image:
    """PIL wrapper to decode_spr_tile"""
    data = decode_spr_tile(spr)
    return Image.frombytes("P", (16, 16), data)


def image_to_sprfile_tile(tile: Image.Image) -> bytes:
    """PIL wrapper to encode_spr_tile"""
    data = tile.tobytes()
    return encode_spr_tile(data)


#
# Utility classes for reading or writing ROM contents
#


class ROMReader:
    """
    Abstract class for reading the contents of a Graphics ROM
    one tile at a time. It is an intermediate class created
    by a subclass of GFXROM, and it is used as an iterator.
    """

    in_ios: List[BinaryIO]

    def __init__(self, in_file: str) -> None:
        self.in_ios = [open(in_file, "rb")]

    def __iter__(self) -> Self:
        return self

    @abstractmethod
    def _read_function(self, ios: List[BinaryIO]) -> bytes:
        return bytes(0)

    def __next__(self) -> bytes:
        try:
            return self._read_function(self.in_ios)
        except EOFError:
            for i in self.in_ios:
                i.close()
            raise StopIteration()


class CROMReader(ROMReader):
    """Iterator for reading tiles from a C-ROM"""

    def __init__(self, in_file1: str, in_file2: str) -> None:
        self.in_ios = [open(in_file1, "rb"), open(in_file2, "rb")]

    def _read_function(self, ios: List[BinaryIO]) -> bytes:
        buf_c1: bytes = ios[0].read(64)
        buf_c2: bytes = ios[1].read(64)
        return decode_crom_tile(buf_c1, buf_c2)


class SROMReader(ROMReader):
    """Iterator for reading tiles from a S-ROM"""

    def _read_function(self, ios: List[BinaryIO]) -> bytes:
        buf: bytes = ios[0].read(32)
        return decode_srom_tile(buf)


class SPRFileReader(ROMReader):
    """Iterator for reading tiles from a SPR file"""

    def _read_function(self, ios: List[BinaryIO]) -> bytes:
        buf: bytes = ios[0].read(128)
        return decode_spr_tile(buf)


class ROMWriter:
    """
    Abstract class for writing tiles data into a Graphics ROM,
    one tile at a time. It is an intermediate class created
    by subclass of GFXROM, and it can be used directly or
    from a context for closing the opened ROM automatically.
    """

    out_ios: List[BinaryIO]

    def __init__(self, out_file: str) -> None:
        self.out_ios = [open(out_file, "wb")]

    def __enter__(self) -> Self:
        return self

    def __exit__(self, type, value, traceback) -> None:
        self.close()

    @abstractmethod
    def write_bytes(self, data: bytes) -> None:
        pass

    def write(self, tile: Image.Image) -> None:
        self.write_bytes(tile.tobytes())

    def add_padding(self, size: int, error_if_overflow=True) -> None:
        if error_if_overflow:
            current = self.out_ios[0].tell()
            if current > size:
                raise ValueError(
                    "ROM larger than requested padding "
                    f"(current: {current}, requested: {size})"
                )
        for i in self.out_ios:
            i.truncate(size)

    def close(self) -> None:
        for i in self.out_ios:
            i.close()


class CROMWriter(ROMWriter):
    """Context and handler for writing tiles to a C-ROM"""

    def __init__(self, out_file1: str, out_file2: str) -> None:
        self.out_ios = [open(out_file1, "wb"), open(out_file2, "wb")]

    def write_bytes(self, data: bytes) -> None:
        data_c1, data_c2 = encode_crom_tile(data)
        self.out_ios[0].write(data_c1)
        self.out_ios[1].write(data_c2)


class SROMWriter(ROMWriter):
    """Context and handler for writing tiles to a S-ROM"""

    def write_bytes(self, data: bytes) -> None:
        data = encode_srom_tile(data)
        self.out_ios[0].write(data)


class SPRFileWriter(ROMWriter):
    """Context and handler for writing tiles to a SPR file"""

    def write_bytes(self, data: bytes) -> None:
        data = encode_spr_tile(data)
        self.out_ios[0].write(data)


#
# Object API for encoding and decoding all tile format (C-ROM, S-ROM, SPR)
#


class GFXROM:
    """
    Abstract class for managing a graphics ROM as a stream of tiles.
    The class allows the writing (or reading) of tiles to (or from)
    an underlying ROM on the filesystem.

    Tiles data are primarily manipulated as PIL images, but they
    can also be handled as raw sequences of bytes (1 byte per pixel).
    """

    tile_size: int = 8
    tile_bytes: int = 32
    file: str

    def __init__(self, file: str) -> None:
        self.file = file

    def __len__(self) -> int:
        return os.path.getsize(self.file) // self.tile_bytes

    @abstractmethod
    def tiles_bytes(self) -> Generator[bytes, None, None]:
        yield bytes()

    def tiles(self) -> Generator[Image.Image, None, None]:
        return (
            Image.frombytes("P", (self.tile_size, self.tile_size), x)
            for x in self.tiles_bytes()
        )

    @abstractmethod
    def writer(self) -> ROMWriter:
        return ROMWriter(self.file)


class SROM(GFXROM):
    """Class for creating or extracting tiles from a S-ROM"""

    tile_size: int = 8
    tile_bytes: int = 32

    def tiles_bytes(self) -> Generator[bytes, None, None]:
        return (t for t in SROMReader(self.file))

    def writer(self) -> SROMWriter:
        return SROMWriter(self.file)


class SPRFile(GFXROM):
    """Class for creating or extracting tiles from a SPR file"""

    tile_size: int = 16
    tile_bytes: int = 128

    def tiles_bytes(self) -> Generator[bytes, None, None]:
        return (t for t in SPRFileReader(self.file))

    def writer(self) -> SPRFileWriter:
        return SPRFileWriter(self.file)


class CROM(GFXROM):
    """Class for creating or extracting tiles from a C-ROM"""

    tile_size: int = 16
    tile_bytes: int = 64
    file2: str

    def __init__(self, file_c1: str, file_c2: str) -> None:
        self.file = file_c1
        self.file2 = file_c2

    def tiles_bytes(self) -> Generator[bytes, None, None]:
        return (t for t in CROMReader(self.file, self.file2))

    def writer(self) -> CROMWriter:
        return CROMWriter(self.file, self.file2)


#
# Utilities functions for creating and iterating over Image objects
#


def empty_image_for_tiles(num_tiles: int, tile_size: int = 8, **kwargs) -> Image.Image:
    """
    Utility function to create a PIL image whose size is sufficient
    to hold a specified number of tiles.

    Either the width or the height of the image must be fixed so
    the right size for the other dimension can be configured. If none
    are given, the image gets a default width of 320 pixels.
    """
    vertical: bool = False
    if "height" in kwargs:
        line_length: int = kwargs["height"]
        vertical = True
    elif "width" in kwargs:
        line_length: int = kwargs["width"]
    else:
        line_length: int = 320
    tiles_per_line: int = line_length // tile_size
    lines: int = (num_tiles + (tiles_per_line - 1)) // tiles_per_line
    if vertical:
        img_width: int = lines * tile_size
        img_height: int = line_length
    else:
        img_width: int = line_length
        img_height: int = lines * tile_size
    img = Image.new("P", (img_width, img_height))
    img.putpalette([0, 0, 0] + [randint(100, 255) for x in range(3, 3 * 16)])
    return img


def tile_positions(
    img: Image.Image, tile_size: int = 8, vertical: bool = False
) -> Generator[tuple[int, int], None, None]:
    """
    Simple generator that yields the position of every tile in
    an image, starting from top left position (0, 0)
    """
    width, height = img.width, img.height
    xrange = range(0, width, tile_size)
    yrange = range(0, height, tile_size)
    if vertical:
        return ((x, y) for x in xrange for y in yrange)
    else:
        return ((x, y) for y in yrange for x in xrange)


#
# Command-line interface
#


def cli_arguments_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Neo Geo graphics ROM management.")

    paction = parser.add_argument_group("action")
    pmode = paction.add_mutually_exclusive_group(required=True)
    pmode.add_argument(
        "-x",
        "-extract",
        action="store_true",
        help="extract tiles from ROM into a 2D image",
    )
    pmode.add_argument(
        "-c",
        "-create",
        action="store_true",
        help="create ROM with tiles from a 2D image",
    )

    ptype = parser.add_mutually_exclusive_group()
    ptype.add_argument("--fix", action="store_true", help="8x8 fix tile mode")
    ptype.add_argument(
        "--sprite", action="store_true", help="16x16 sprite tile mode [default]"
    )
    ptype.add_argument(
        "--cd-sprite", action="store_true", help="16x16 CD sprite tile mode"
    )

    parser.add_argument("FILE", nargs="+", help="file to process")
    parser.add_argument("-o", "--output", nargs="+", help="name of output file")

    parser.add_argument(
        "-s",
        "--size",
        metavar="BYTES",
        type=int,
        help="size of the generated ROM (create)",
    )
    parser.add_argument(
        "-w",
        "--width",
        metavar="PIXELS",
        type=int,
        help="width of the generated 2D image (extract)",
    )

    parser.add_argument(
        "-v",
        "--verbose",
        dest="verbose",
        action="store_true",
        help="print details of processing",
    )
    return parser


def error(str: str, error_code: int = 1):
    prog_name = os.path.basename(sys.argv[0])
    sys.exit(f"{prog_name}: error: {str}")


def cli_main():

    arguments = cli_arguments_parser().parse_args()

    # filename order depends on the actions to execute
    image_name: str = arguments.output[0] if arguments.x else arguments.FILE[0]
    rom_args: List[str] = arguments.FILE if arguments.x else arguments.output

    # input checks
    if arguments.x:
        for r in rom_args:
            if not os.path.exists(r):
                error(f"file does not exist: {r}")
        if arguments.sprite:
            if os.path.getsize(rom_args[0]) != os.path.getsize(rom_args[1]):
                error("input C-ROMs have different sizes")
    elif arguments.c:
        if not os.path.exists(image_name):
            error(f"file does not exist: {image_name}")

    # type of graphics ROM
    if arguments.fix:
        rom = SROM(rom_args[0])
    elif arguments.cd_sprite:
        rom = SPRFile(rom_args[0])
    else:
        rom = CROM(rom_args[0], rom_args[1])

    # image info
    tile_size: int = 8 if arguments.fix else 16
    tile_strip_in_pixels: int = arguments.width if arguments.width is not None else 320
    if tile_strip_in_pixels % tile_size != 0:
        error(
            f"image constraint is not a multiple of {tile_size}"
            f" (requested: {tile_strip_in_pixels})"
        )

    try:
        # mode: ROM extraction
        if arguments.x:
            num_tiles = len(rom)
            image = empty_image_for_tiles(
                len(rom), tile_size, width=tile_strip_in_pixels
            )
            if arguments.verbose:
                (width, height) = (image.width, image.height)
                out_tiles = (width // tile_size) * (height // tile_size)
                print(f"input has {num_tiles} tiles")
                print(
                    f"destination will hold {out_tiles} tiles ({width}px x {height}px)"
                )
            positions = tile_positions(image, tile_size)
            for tile in rom.tiles():
                image.paste(tile, next(positions))
            image.save(image_name)

        # mode: ROM creation
        elif arguments.c:
            image = Image.open(image_name, "r")
            if (image.width % tile_size != 0) or (image.height % tile_size != 0):
                error(f"image dimensions are not multiple of {tile_size}")
            with rom.writer() as w:
                for x, y in tile_positions(image, tile_size):
                    tile = image.crop((x, y, x + tile_size, y + tile_size))
                    w.write(tile)
                # optional padding
                if arguments.size:
                    w.add_padding(arguments.size)
    except Exception as e:
        error(f"{e}")


if __name__ == "__main__":
    cli_main()
