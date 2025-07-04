#!/usr/bin/env python3
# Copyright (c) 2024 Damien Ciabrini
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

"""vromtool.py - pack ADPCM samples in ROM and generate offset map."""

import argparse
import base64
import os
import sys
from dataclasses import dataclass
from furtool import samples_from_module
from struct import pack, unpack, unpack_from
import wave
from adpcmtool import ym2610_adpcma, ym2610_adpcmb

import yaml

VERBOSE = False


def error(s):
    sys.exit("error: "+s)


def dbg(s):
    if VERBOSE:
        print(s, file=sys.stderr)


@dataclass
class furnace:
    name: str = ""
    uri: str = ""

@dataclass
class adpcm_a:
    name: str = ""
    uri: str = ""

@dataclass
class adpcm_b:
    name: str = ""
    uri: str=""


# Minimal input validation
# NOTE this should be done with a validator package
def validate(s):
    assert isinstance(s, dict)
    assert len(s.keys()) == 1
    assert list(s.keys())[0].lower() in ['furnace', 'adpcm_a', 'adpcm_b']
    val = s[list(s.keys())[0]]
    assert isinstance(val, dict)
    assert all([x in val and isinstance(val[x], str) for x in ["name", "uri"]])
    assert val["uri"].startswith("file://") or \
           val["uri"].startswith("data:;base64,")


# Basic sample packing: allocate ADPCM samples in sequence
# until a ROM is full. Assume ADPCM A and B share the same ROM
def allocate_samples(smp, vrom_size, out_vrom_pattern):
    dbg("Allocating samples into VROMs")
    adpcm_pos = vrom_size
    vrom = 0
    f = None
    for s in smp:
        if adpcm_pos+len(s.data) > vrom_size:
            if f:
                f.close()
            adpcm_pos = 0
            vrom += 1
            out = out_vrom_pattern.replace("X", str(vrom))
            dbg("  New VROM '%s'" % out)
        s.out = out
        s.start = adpcm_pos
        s.length = len(s.data)
        s.start_lsb = (s.start >> 8) & 0xff
        s.start_msb = (s.start >> 16) & 0xff
        s.stop_lsb = ((s.start+s.length-1) >> 8) & 0xff
        s.stop_msb = ((s.start+s.length-1) >> 16) & 0xff
        dbg("    [%06x..%06x / %06x] %s" % (s.start, s.start+s.length, vrom_size, s.name))
        adpcm_pos += s.length


# Save samples to VROMs on disk
def generate_vroms(smp, vrom_size, out_vrom_pattern, nb_vroms):
    dbg("Generating VROMs")
    for vrom in range(1, nb_vroms+1):
        out = out_vrom_pattern.replace("X", str(vrom))
        with open(out, "wb") as f:
            dbg("  %s" % out)
            romsmp = filter(lambda r: r.out == out, smp)
            for r in romsmp:
                f.seek(r.start)
                f.write(r.data)
            f.truncate(vrom_size)


# Generate ASM defines for all the samples stored in ROMs
def generate_asm_defines(smp, f):
    print(";;; ADPCM samples map in VROM", file=f)
    print(";;; generated by vromtool.py (ngdevkit)", file=f)
    print("", file=f)

    stype = {adpcm_a: "ADPCM-A", adpcm_b: "ADPCM-B"}
    for s in smp:
        print(";;; %s" % s.name, file=f)
        rom = os.path.basename(s.out)
        start = s.start >> 8
        stop = (s.start+s.length-1) >> 8
        print(";;; %s [%04x00..%04xff] %s" % (rom, start, stop, stype[type(s)]), file=f)
        print("        .equ    %s_START_LSB, 0x%02x" % (s.name.upper(), s.start_lsb), file=f)
        print("        .equ    %s_START_MSB, 0x%02x" % (s.name.upper(), s.start_msb), file=f)
        print("        .equ    %s_STOP_LSB, 0x%02x" % (s.name.upper(), s.stop_lsb), file=f)
        print("        .equ    %s_STOP_MSB, 0x%02x" % (s.name.upper(), s.stop_msb), file=f)
        print("", file=f)

def convert_to_adpcm(sample, path):
    codec = {"adpcm_a": ym2610_adpcma,
             "adpcm_b": ym2610_adpcmb}[sample.__class__.__name__]()
    try:
        w = wave.open(path, 'rb')
        assert w.getnchannels() == 1, "Only mono WAV file is supported"
        assert w.getcomptype() == 'NONE', "Only uncompressed WAV file is supported"
        nframes = w.getnframes()
        data = w.readframes(nframes)
    except Exception as e:
        error("Could not convert sample '%s' to ADPCM: %s"%(path, e))

    if w.getsampwidth() == 1:
        # WAV file format, 8bits is always unsigned
        pcm8s = unpack('<%dB' % (len(data)), data)
        adpcms=codec.encode_u8(pcm8s)
    else:
        # WAV file format, 16bits is always signed
        pcm16s = unpack('<%dh' % (len(data)>>1), data)
        adpcms=codec.encode_s16(pcm16s)

    adpcms_packed = [(adpcms[i] << 4 | adpcms[i+1]) for i in range(0, len(adpcms), 2)]
    return bytes(adpcms_packed)

def load_sample_map_file(filenames):
    # Allow multiple documents in the yaml file
    all_ysamples = []
    for filename in filenames:
        ysamples = []
        with open(filename, "rb") as f:
            yamlblocks = list(yaml.load_all(f, yaml.Loader))
        for b in yamlblocks:
            ysamples.extend(b)
        all_ysamples.extend([filename, y] for y in ysamples)
    dbg("Found %d entries in file(s): %s" % (len(all_ysamples), ", ".join(filenames)))

    # Create adpcm objects from input map and load sample data
    samples = []
    mkmap = {"adpcm_a_sample": adpcm_a,
             "adpcm_b_sample": adpcm_b,
             "adpcm_a": adpcm_a,
             "adpcm_b": adpcm_b}
    for mapfile, y in all_ysamples:
        validate(y)
        stype = list(y.keys())[0]
        if stype == 'furnace':
            # extract all sample object from the furnace module
            modfile=y['furnace']['uri'][7:]
            smp = samples_from_module(modfile)
            for s in smp:
                dbg("  %s: loaded from furnace module '%s'" % (s.name, modfile))
                vs = mkmap[s.__class__.__name__](s.name)
                vs.data = s.data
                samples.append(vs)
        else:
            # make a sample object from the input
            sample = mkmap[stype](y[stype]["name"], y[stype]["uri"])
            # load sample's data
            if sample.uri.startswith("file://"):
                samplepath = sample.uri[7:]
                if samplepath.endswith(".wav"):
                    sample.data = convert_to_adpcm(sample, samplepath)
                else:
                    with open(samplepath, "rb") as f:
                        sample.data = f.read()
                dbg("  %s: loaded from '%s'" % (sample.name, samplepath))
            elif sample.uri.startswith("data:;base64,"):
                dbg("  %s: encoded in '%s'" % (sample.name, mapfile))
                sample.data = base64.b64decode(sample.uri[13:])
            else:
                error("unknown URI for sample '%s'"%sample.name)
            samples.append(sample)

    return samples


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description="Manage ADPCM sample offsets in VROMs")

    paction = parser.add_argument_group("action")
    pmode = paction.add_mutually_exclusive_group(required=True)
    pmode.add_argument("-r", "--roms", action="store_const",
                       const="roms", dest="action",
                       help="generate VROMs out of ADPCM map files")
    pmode.add_argument("-a", "--asm", action="store_const",
                       const="asm", dest="action", default="asm",
                       help="dump offsets in ASM format out of ADPCM map files")

    parser.add_argument("FILE", nargs="+",
                        help="ADPCM map file to process")
    parser.add_argument("-o", "--output", required=True,
                        help="Output file path. When generating multiple VROMs, the"\
                        " basename will substitute 'X' for the ROM number")

    parser.add_argument("-m", "--output-map",
                        help="Output sample map offsets as ASM defines")

    parser.add_argument("-s", "--size",
                        type=int, required=True,
                        help="size of one VROM in bytes")

    parser.add_argument("-n", "--nb",
                        type=int, default="1",
                        help="number of VROMs to generate")

    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                        default=False, help="print details of processing")

    arguments = parser.parse_args()
    VERBOSE = arguments.verbose

    # load all samples data in memory from the map file
    samples = load_sample_map_file(arguments.FILE)

    # allocate samples in ROMs
    allocate_samples(samples,
                     vrom_size=arguments.size,
                     out_vrom_pattern=arguments.output)

    if arguments.action == "asm":
        if arguments.output_map:
            with open(arguments.output_map, "w") as f:
                generate_asm_defines(samples, f)
        else:
            generate_asm_defines(samples, sys.__stdout__)

    elif arguments.action == "roms":
        generate_vroms(samples,
                       vrom_size=arguments.size,
                       out_vrom_pattern=arguments.output,
                       nb_vroms=arguments.nb)
    else:
        error("Unknown action: %s" % arguments.action)


if __name__ == "__main__":
    main()
