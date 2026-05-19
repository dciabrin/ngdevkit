#!/usr/bin/env python
# Copyright (c) 2026 Damien Ciabrini
# This file is part of ngdevkit
#
# ngdevkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# ngdevkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of`
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

import argparse
import sys
import os
from datetime import datetime
import hashlib
import typing
import zlib
import struct
import zipfile

from dataclasses import dataclass, field
from enum import IntEnum


#
# romtool API
#


@dataclass
class ROM:
    """
    The representation of a single ROM chip inside a cartrige.
    """

    # Name of the ROM file
    name: str
    # destination address in ROM address space
    dest: int
    # size of ROM data
    size: int
    # ROM data checksum (CRC32)
    crc: int = field(repr=False)
    # ROM data checksum (SHA1)
    sha1: str = field(repr=False)
    # path of the ROM file on disk
    path: str = field(repr=False)


@dataclass
class Cartridge:
    """
    The cartridge is the main entry point that represents a full game.
    It is composed of a series of ROM objects (68k code, GFX, sound...)
    """

    # Name of the cartridge file
    name: str
    # Human-readable name of the game
    long_name: str
    # Year of publishing
    year: int
    # Publisher
    publisher: str
    # All the P-ROMs (68k) in this cartridge
    proms: list[ROM]
    # All the M-ROMs (Z80) in this cartridge
    mroms: list[ROM]
    # All the V-ROMs (ADPCM) in this cartridge
    vroms: list[ROM]
    # All the S-ROMs (fixed tiles) in this cartridge
    sroms: list[ROM]
    # All the C-ROMs (sprite tiles) in this cartridge
    croms: list[ROM]


OptionType: typing.TypeAlias = typing.Dict[str, "OptionValue"]
OptionValue: typing.TypeAlias = str | OptionType


def make_cartridge(
    name: str,
    long_name: str,
    year: int,
    publisher: str,
    pfiles: list[str],
    mfiles: list[str],
    vfiles: list[str],
    sfiles: list[str],
    cfiles: list[str],
) -> Cartridge:
    """
    Return a python object that represent a game cartridge, composed of
    all the binary ROM files passed in parameter.
    """

    def hashes(path: str) -> tuple[int, str]:
        with open(path, "rb") as f:
            data = f.read()
            crc = zlib.crc32(data)
            sha1 = hashlib.sha1(data).hexdigest()
            return crc, sha1

    def make_roms(paths: list[str], crom: bool = False) -> list[ROM]:
        out: list[ROM] = []
        area_dst = 0
        sub_offset = 0
        for p in paths:
            filename = os.path.basename(p)
            rom_dst = area_dst + sub_offset
            size = os.path.getsize(p)
            crc, sha1 = hashes(p)
            out.append(ROM(filename, rom_dst, size, crc, sha1, p))
            if crom:
                sub_offset = (sub_offset + 1) % 2
            if sub_offset == 0:
                area_dst += size
        return out

    proms = make_roms(pfiles)
    mroms = make_roms(mfiles)
    vroms = make_roms(vfiles)
    sroms = make_roms(sfiles)
    croms = make_roms(cfiles, crom=True)

    return Cartridge(
        name, long_name, year, publisher, proms, mroms, vroms, sroms, croms
    )


#
# GnGeo specialization, encoding and decoding functions
#


class GnGeoRegion(IntEnum):
    AUDIO_CPU_BIOS = 0
    AUDIO_CPU_CARTRIDGE = 1
    AUDIO_CPU_ENCRYPTED = 2
    AUDIO_DATA_1 = 3
    AUDIO_DATA_2 = 4
    FIXED_LAYER_BIOS = 5
    FIXED_LAYER_CARTRIDGE = 6
    MAIN_CPU_BIOS = 7
    MAIN_CPU_CARTRIDGE = 8
    SPRITES = 9
    SPR_USAGE = 10
    GAME_FIX_USAGE = 11


def gngeo_drv(cart: Cartridge) -> bytes:
    """
    Create a GnGeo drv file for the input Cartridge.
    """
    desc_roms: list[tuple[GnGeoRegion, list[ROM]]] = [
        (GnGeoRegion.MAIN_CPU_CARTRIDGE, cart.proms),
        (GnGeoRegion.AUDIO_CPU_CARTRIDGE, cart.mroms),
        (GnGeoRegion.AUDIO_DATA_1, cart.vroms),
        (GnGeoRegion.FIXED_LAYER_CARTRIDGE, cart.sroms),
        (GnGeoRegion.SPRITES, cart.croms),
    ]
    rom_sizes: list[int] = [0] * 10
    nb_roms = 0
    for region, roms in desc_roms:
        rom_sizes[region] = sum([r.size for r in roms])
        nb_roms += len(roms)
    out = bytearray()
    out += struct.pack("32s", cart.name[:31].encode())
    out += struct.pack("32s", "neogeo".encode())
    out += struct.pack("128s", cart.long_name[:127].encode())
    out += struct.pack("<I", cart.year)
    out += struct.pack("<10I", *rom_sizes)
    out += struct.pack("<I", nb_roms)
    for region, roms in desc_roms:
        for rom in roms:
            out += struct.pack("32s", rom.name[:31].encode())
            out += struct.pack("B", region)
            out += struct.pack("<I", 0)
            out += struct.pack("<I", rom.dest)
            out += struct.pack("<I", rom.size)
            out += struct.pack("<I", rom.crc)
    return bytes(out)


def gngeo_build_hash(cart: Cartridge, output: str, **kwargs: OptionType):
    """
    Create a GnGeo hash file for the input Cartridge.
    NOTE: GnGeo hashes file are read from the single data file 'gngeo_data.zip'
    that contains GnGeo resources, so we need to build a compatible data file
    to embed the hash file in it.
    """
    if "data" not in kwargs:
        raise ValueError(
            "keyword 'data' must point to path of GnGeo's 'gngeo_data.zip'"
        )
    if not isinstance(kwargs["data"], str):
        raise ValueError("keyword 'data' must be of type str")

    gngeo_orig_data = kwargs["data"]
    if not os.path.exists(gngeo_orig_data):
        raise ValueError(f"original file {gngeo_orig_data} not found")

    with (
        zipfile.ZipFile(gngeo_orig_data, "r") as gzf,
        zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zf,
    ):
        # save ROM driver
        zf.mkdir("rom", mode=0o711)
        with zf.open(f"rom/{cart.name}.drv", "w") as f:
            f.write(gngeo_drv(cart))

        # inject GnGeo original skin data
        zf.mkdir("skin", mode=0o711)
        skin_files = [n for n in gzf.namelist() if "skin/" in n and n != "skin/"]
        for f in skin_files:
            with gzf.open(f, "r") as fi, zf.open(f, "w") as fo:
                fo.write(fi.read())
        with zf.open("skin/README.md", "w") as f:
            f.write(
                b"This directory contains original GnGeo data files, licensed under the GPLv2"
            )


#
# MAME specialization, encoding functions (ROM and hash)
#


mame_hash_tpl = """<?xml version="1.0"?>
<!DOCTYPE softwarelist SYSTEM "softwarelist.dtd">
<!-- Generated by romtool (ngdevkit) -->

<softwarelist name="neogeo" description="Neo-Geo cartridges">
\t<software name="{name}">
\t\t<description>{long_name}</description>
\t\t<year>{year}</year>{info_tags}
\t\t<sharedfeat name="release" value="{sharedfeat[release]}" />
\t\t<sharedfeat name="compatibility" value="{sharedfeat[compatibility]}" />
\t\t<publisher>{publisher}</publisher>
\t\t<part name="cart" interface="neo_cart">
\t\t\t<dataarea name="maincpu" width="16" endianness="big" size="0x{size[proms]:05x}">{entries[proms]}
\t\t\t</dataarea>
\t\t\t<dataarea name="fixed" size="0x{size[sroms]:05x}">{entries[sroms]}
\t\t\t</dataarea>
\t\t\t<dataarea name="audiocpu" size="0x{size[mroms]:05x}">{entries[mroms]}
\t\t\t</dataarea>
\t\t\t<dataarea name="ymsnd:adpcma" size="0x{size[vroms]:05x}">{entries[vroms]}
\t\t\t</dataarea>
\t\t\t<dataarea name="sprites" size="0x{size[croms]:05x}">{entries[croms]}
\t\t\t</dataarea>
\t\t</part>
\t</software>
</softwarelist>
"""


def mame_build_hash(cart: Cartridge, output: str, **kwargs: OptionType):
    """
    Create a MAME hash file for the input Cartridge
    """
    global mame_hash_tpl

    entries: dict[str, str] = {}
    size: dict[str, int] = {}
    for region, roms, extra in (
        ("proms", cart.proms, 'loadflag="load16_word_swap" '),
        ("mroms", cart.mroms, ""),
        ("vroms", cart.vroms, ""),
        ("sroms", cart.sroms, ""),
        ("croms", cart.croms, 'loadflag="load16_byte" '),
    ):
        files = []
        for rom in roms:
            buf = f'\n\t\t\t\t<rom {extra}name="{rom.name}"'
            buf += f' offset="0x{rom.dest:06x}" size="0x{rom.size:06x}"'
            buf += f' crc="{rom.crc:08x}" sha1="{rom.sha1}" />'
            files.append(buf)
        entries[region] = "".join(files)
        size[region] = sum([rom.size for rom in roms])

    info = kwargs.get("info", {})
    if not isinstance(info, dict):
        raise ValueError("'info' keyword must be a dict")
    info_tags = ""
    for name, value in info.items():
        info_tags += f'\n\t\t<info name="{name}" value="{value}"/>'

    # default substitutions for the hash file
    env: OptionType = {
        "name": cart.name,
        "long_name": cart.long_name,
        "year": str(cart.year),
        "info_tags": info_tags,
        "sharedfeat": {"release": "MVS,AES", "compatibility": "MVS,AES"},
        "publisher": cart.publisher,
    }
    # extend with optional keywords
    for n, v in kwargs.items():
        oldv = env.get(n, "")
        if isinstance(oldv, dict) and isinstance(v, dict):
            oldv.update(v)
        else:
            env[n] = v

    out_str = mame_hash_tpl.format(**(env | {"entries": entries, "size": size}))
    with open(output, "w") as f:
        print(out_str, file=f)


#
# ZIP specialization, ROM build function
#


def zip_build_cartridge(cart: Cartridge, output: str, **kwargs: OptionType):
    """
    Build a cartridge file as a ZIP archive
    """
    all_roms = cart.proms + cart.mroms + cart.vroms + cart.sroms + cart.croms
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in [r.path for r in all_roms]:
            zf.write(path, os.path.basename(path))
        if "comment" in kwargs and isinstance(kwargs["comment"], str):
            zf.comment = kwargs["comment"].encode()


#
# Command-line interface
#


def error(str: str, error_code: int = 1):
    prog_name = os.path.basename(sys.argv[0])
    sys.exit(f"{prog_name}: error: {str}")


def build_extra_dict(extra: list[str]) -> OptionType:
    """
    Convert a list of generic config arguments 'x.y.z=foo' into
    a nested dictionary, whose keys are valid Python identifiers.
    """
    out_dict: OptionType = {}

    def build(cur_dict, key, *vals) -> OptionType:
        if len(vals) == 1:
            return {key: vals[0]}
        else:
            sub_dict = cur_dict.get(key, {})
            sub_dict.update(build(sub_dict, vals[0], *vals[1:]))
            cur_dict[key] = sub_dict
            return cur_dict

    for e in extra:
        keystr, val = e.split("=", 1)
        if "=" in val:
            error(f"invalid extra option: '{e}': multiple '=' signs")
        keys = keystr.split(".")
        if any([not k.isidentifier() for k in keys]):
            error(f"invalid extra option '{keystr}': invalid identifiers")
        fullpath = keys + [val]
        build(out_dict, *fullpath)
    return out_dict


def cli_arguments_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Neo Geo ROM management.")

    parser.add_argument(
        "-b", "--build", help="Build action (cartridge, hash)", default="cartridge"
    )

    parser.add_argument(
        "-f", "--format", help="ROM format (mame, gngeo)", default="mame"
    )

    parser.add_argument(
        "-p",
        "--prom",
        action="extend",
        nargs="+",
        help="program ROM files",
        required=True,
    )
    parser.add_argument(
        "-m",
        "--mrom",
        action="extend",
        nargs="+",
        help="sound driver ROM files",
        required=True,
    )
    parser.add_argument(
        "-v",
        "--vrom",
        action="extend",
        nargs="+",
        help="ADPCM ROM files",
        required=True,
    )
    parser.add_argument(
        "-s",
        "--srom",
        action="extend",
        nargs="+",
        help="fixed graphics ROM files",
        required=True,
    )
    parser.add_argument(
        "-c",
        "--crom",
        action="extend",
        nargs="+",
        help="sprite graphics ROM files",
        required=True,
    )

    parser.add_argument("-n", "--name", help="game name", required=True)
    parser.add_argument("-l", "--long-name", help="long descriptive game name")
    parser.add_argument("-y", "--year", type=int, help="publishing year")
    parser.add_argument("--publisher", help="publisher")
    parser.add_argument("-o", "--output", help="name of output file")

    parser.add_argument(
        "-x",
        "--extra",
        action="extend",
        nargs="+",
        help="emulator-specific extra config",
        default=[],
    )

    parser.add_argument(
        "--verbose",
        dest="verbose",
        action="store_true",
        help="print details of processing",
    )
    return parser


def cli_main():

    args = cli_arguments_parser().parse_args()

    name = args.name
    long_name = args.long_name if args.long_name else name
    year = args.year if args.year else datetime.now().year
    publisher = args.publisher if args.publisher else "Unpublished"
    extra: OptionType = build_extra_dict(args.extra)

    c_len = len(args.crom)
    if c_len % 2 != 0:
        error(f"C-ROM must be provided in pair (*.c1, *.c2 ...), {c_len} given")
    for r in args.prom + args.mrom + args.vrom + args.srom + args.crom:
        if not os.path.exists(r):
            error(f"ROM {r} does not exists")
        if not os.path.isfile(r):
            error(f"ROM {r} is not a regular file")
        s = os.path.getsize(r)
        if s & (s - 1) != 0:
            error(f"ROM size {r} must be a power of two, {s} found")

    if args.build == "hash" and args.format == "gngeo":
        if not ("gngeo" in extra and "data" in extra["gngeo"]):
            error(
                'you must pass -x gngeo.data="<path_to_original_gngeo_data.zip>"'
                + "to build a GnGeo hash file."
            )
        gngeo_orig_data = extra["gngeo"]["data"]
        if not os.path.exists(gngeo_orig_data):
            raise error(f"original GnGeo hash file {gngeo_orig_data} not found")

    cart = make_cartridge(
        name,
        long_name,
        year,
        publisher,
        args.prom,
        args.mrom,
        args.vrom,
        args.srom,
        args.crom,
    )

    if args.build == "hash":
        if args.format == "mame":
            mame_build_hash(cart, args.output, **extra.get("mame", {}))
        elif args.format == "gngeo":
            gngeo_build_hash(cart, args.output, **extra.get("gngeo", {}))
    elif args.build == "cartridge":
        zip_build_cartridge(cart, args.output, **extra.get("zip", {}))


if __name__ == "__main__":
    cli_main()
