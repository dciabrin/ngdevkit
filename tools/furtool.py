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

"""furtool.py - extract instruments and samples from a Furnace module."""

import argparse
import base64
import re
import sys
import zlib
from dataclasses import dataclass, field
from struct import pack, unpack_from

VERBOSE = False


def error(s):
    sys.exit("error: " + s)


def dbg(s):
    if VERBOSE:
        print(s, file=sys.stderr)


class binstream(object):
    def __init__(self, data=b""):
        self.data = bytearray(data)
        self.pos = 0

    def bytes(self):
        return bytes(self.data)

    def eof(self):
        return self.pos == len(self.data)

    def read(self, n):
        res = self.data[self.pos:self.pos + n]
        self.pos += n
        return res

    def seek(self, pos):
        self.pos = pos

    def u1(self):
        res = unpack_from("B", self.data, self.pos)[0]
        self.pos += 1
        return res

    def u2(self):
        res = unpack_from("<H", self.data, self.pos)[0]
        self.pos += 2
        return res

    def u4(self):
        res = unpack_from("<I", self.data, self.pos)[0]
        self.pos += 4
        return res

    def uf4(self):
        res = unpack_from("<f", self.data, self.pos)[0]
        self.pos += 4
        return res

    def ustr(self):
        res = []
        b = self.u1()
        while b != 0:
            res.append(b)
            b = self.u1()
        return bytearray(res).decode("utf-8")

    def write(self, data):
        self.data.extend(data)
        self.pos += len(data)

    def e1(self, data):
        self.data.extend(pack("B", data))
        self.pos += 1

    def e2(self, data):
        self.data.extend(pack("<H", data))
        self.pos += 2

    def e4(self, data):
        self.data.extend(pack("<I", data))
        self.pos += 4


def ubit(data, msb, lsb):
    mask = (2 ** (msb - lsb + 1)) - 1
    return (data >> lsb) & mask


def ubits(data, *args):
    res = []
    for a in args:
        res.append(ubit(data, a[0], a[1]))
    return res


def ebit(data, msb, lsb):
    return (data << lsb)


@dataclass
class fur_module:
    name: str = ""
    author: str = ""
    instruments: list[int] = field(default_factory=list)
    samples: list[int] = field(default_factory=list)


def read_module(bs):
    mod = fur_module()
    assert bs.read(16) == b"-Furnace module-"  # magic
    bs.u2()  # version
    bs.u2()
    infodesc = bs.u4()
    bs.seek(infodesc)
    assert bs.read(4) == b"INFO"
    bs.read(18)  # skip
    nb_instruments = bs.u2()
    nb_wavetables = bs.u2()
    nb_samples = bs.u2()
    nb_patterns = bs.u4()
    chips = [x for x in bs.read(32)]
    assert chips[:chips.index(0)] == [165]  # single ym2610 chip
    bs.read(32 + 32 + 128)  # skip chips vol, pan, flags
    mod.name = bs.ustr()
    mod.author = bs.ustr()
    bs.uf4()  # skip tuning
    bs.read(20)  # skip furnace configs
    mod.instruments = [bs.u4() for i in range(nb_instruments)]
    _ = [bs.u4() for i in range(nb_wavetables)]
    mod.samples = [bs.u4() for i in range(nb_samples)]
    _ = [bs.u4() for i in range(nb_patterns)]
    return mod


@dataclass
class fm_operator:
    detune: int = 0
    multiply: int = 0
    total_level: int = 0
    key_scale: int = 0
    attack_rate: int = 0
    am_on: int = 0
    decay_rate: int = 0
    kvs: int = 0
    sustain_rate: int = 0
    sustain_level: int = 0
    release_rate: int = 0
    ssg_eg: int = 0


@dataclass
class adpcm_a_sample:
    name: str = ""
    data: bytearray = field(default=b"", repr=False)


@dataclass
class adpcm_b_sample:
    name: str = ""
    data: bytearray = field(default=b"", repr=False)


@dataclass
class fm_instrument:
    name: str = ""
    algorithm: int = 0
    feedback: int = 0
    am_sense: int = 0
    fm_sense: int = 0
    ops: list[fm_operator] = field(default_factory=list)


@dataclass
class adpcm_a_instrument:
    name: str = ""
    sample: adpcm_a_sample = None


@dataclass
class adpcm_b_instrument:
    name: str = ""
    sample: adpcm_b_sample = None


def read_fm_instrument(bs):
    ifm = fm_instrument()
    assert bs.u1() == 0xf4  # data for all operators
    ifm.algorithm, ifm.feedback = ubits(bs.u1(), [6, 4], [2, 0])
    ifm.am_sense, ifm.fm_sense = ubits(bs.u1(), [4, 3], [2, 0])
    bs.u1()  # unused
    for _ in range(4):
        op = fm_operator()
        op.detune, op.multiply = ubits(bs.u1(), [6, 4], [3, 0])
        (op.total_level,) = ubits(bs.u1(), [6, 0])
        # RS is env_scale in furnace UI. key_scale in wiki?
        op.key_scale, op.attack_rate = ubits(bs.u1(), [7, 6], [4, 0])
        # KSL todo
        op.am_on, op.decay_rate = ubits(bs.u1(), [7, 7], [4, 0])
        op.kvs, op.sustain_rate = ubits(bs.u1(), [6, 5], [4, 0])
        op.sustain_level, op.release_rate = ubits(bs.u1(), [7, 4], [3, 0])
        (op.ssg_eg,) = ubits(bs.u1(), [3, 0])
        bs.u1()  # unused
        ifm.ops.append(op)
    return ifm


def read_instrument(bs, smp):
    assert bs.read(4) == b"INS2"
    endblock = bs.pos + bs.u4()
    assert bs.u2() >= 127  # format version
    itype = bs.u2()
    assert itype in [1, 37, 38]  # FM, ADPCM-A, ADPCM-B
    # for when the instrument has no SM feature
    sample = 0
    while bs.pos < endblock:
        feat = bs.read(2)
        length = bs.u2()
        if feat == b"NA":
            name = bs.ustr()
        elif feat == b"FM":
            ins = read_fm_instrument(bs)
        elif feat == b"LD":
            # unused OPL drum data
            bs.read(length)
        elif feat == b"SM":
            sample = bs.u2()
            bs.u2()  # unused flags and waveform
        else:
            print("unexpected feature: %s" % feat.decode())
            bs.read(length)
    # for ADPCM sample, populate sample data
    if itype in [37, 38]:
        ins = {37: adpcm_a_instrument,
               38: adpcm_b_instrument}[itype]()
        ins.sample = smp[sample]
    # generate a ASM name for the instrument
    ins.name = re.sub(r"\W|^(?=\d)", "_", name).lower()
    return ins


def read_instruments(ptrs, smp, bs):
    ins = []
    for p in ptrs:
        bs.seek(p)
        ins.append(read_instrument(bs, smp))
    return ins


def read_sample(bs):
    assert bs.read(4) == b"SMP2"
    _ = bs.u4()  # endblock
    name = bs.ustr()
    adpcm_samples = bs.u4()
    data_bytes = adpcm_samples // 2

    assert adpcm_samples % 2 == 0
    assert data_bytes % 256 == 0
    _ = bs.u4()  # unused compat frequency
    c4_freq = bs.u4()
    stype = bs.u1()
    assert stype in [5, 6]  # ADPCM-A, ADPCM-B
    assert c4_freq == {5: 18500, 6: 44100}[stype]
    bs.u1()  # unused play direction
    bs.u2()  # unused flags
    bs.read(8)  # unused looping info
    bs.read(16)  # unused rom allocation
    data = bs.read(data_bytes)
    # generate a ASM name for the instrument
    insname = re.sub(r"\W|^(?=\d)", "_", name).lower()
    ins = {5: adpcm_a_sample,
           6: adpcm_b_sample}[stype](insname, data)
    return ins


def read_samples(ptrs, bs):
    smp = []
    for p in ptrs:
        bs.seek(p)
        smp.append(read_sample(bs))
    return smp


def asm_fm_instrument(ins, fd):
    dtmul = tuple(ebit(ins.ops[i].detune, 6, 4) | ebit(ins.ops[i].multiply, 3, 0) for i in range(4))
    tl = tuple(ebit(ins.ops[i].total_level, 6, 0) for i in range(4))
    ksar = tuple(ebit(ins.ops[i].key_scale, 7, 6) | ebit(ins.ops[i].attack_rate, 4, 0) for i in range(4))
    amdr = tuple(ebit(ins.ops[i].am_on, 7, 7) | ebit(ins.ops[i].decay_rate, 4, 0) for i in range(4))
    sr = tuple(ebit(ins.ops[i].kvs, 6, 5) | ebit(ins.ops[i].sustain_rate, 4, 0) for i in range(4))
    slrr = tuple(ebit(ins.ops[i].sustain_level, 7, 4) | ebit(ins.ops[i].release_rate, 3, 0) for i in range(4))
    ssgeg = tuple(ebit(ins.ops[i].ssg_eg, 3, 0) for i in range(4))
    fbalgo = (ebit(ins.feedback, 5, 3) | ebit(ins.algorithm, 2, 0),)
    amsfms = (ebit(0b11, 7, 6) | ebit(ins.am_sense, 5, 4) | ebit(ins.fm_sense, 2, 0),)
    print("%s:" % ins.name, file=fd)
    print("        ;;       OP1 - OP3 - OP2 - OP4", file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; DT | MUL" % dtmul, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; TL" % tl, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; KS | AR" % ksar, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; AM | DR" % amdr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SR" % sr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SL | RR" % slrr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SSG" % ssgeg, file=fd)
    print("        .db     0x%02x                     ; FB | ALGO" % fbalgo, file=fd)
    print("        .db     0x%02x                     ; LR | AMS | FMS" % amsfms, file=fd)
    print("", file=fd)


def asm_adpcm_instrument(ins, fd):
    name = ins.sample.name.upper()
    print("%s:" % ins.name, file=fd)
    print("        .db     %s_START_LSB, %s_START_MSB  ; start >> 8" % (name, name), file=fd)
    print("        .db     %s_STOP_LSB,  %s_STOP_MSB   ; stop  >> 8" % (name, name), file=fd)
    print("", file=fd)


def generate_instruments(mod, sample_map_name, ins_name, ins, fd):
    print(";;; NSS instruments - generated by furtool.py (ngdevkit)", file=fd)
    print(";;; ---", file=fd)
    print(";;; Song title: %s" % mod.name, file=fd)
    print(";;; Song author: %s" % mod.author, file=fd)
    print(";;;", file=fd)
    print("", file=fd)
    print("        .area   CODE", file=fd)
    print("", file=fd)
    print("        ;; offset of ADPCM samples in ROMs", file=fd)
    print('        .include "%s"' % sample_map_name, file=fd)
    print("", file=fd)
    inspp = {fm_instrument: asm_fm_instrument,
             adpcm_a_instrument: asm_adpcm_instrument,
             adpcm_b_instrument: asm_adpcm_instrument}
    print("%s::" % ins_name, file=fd)
    for i in ins:
        print("        .dw     %s" % i.name, file=fd)
    print("", file=fd)
    for i in ins:
        inspp[type(i)](i, fd)


def generate_sample_map(mod, smp, fd):
    print("# ADPCM sample map - generated by furtool.py (ngdevkit)", file=fd)
    print("# ---", file=fd)
    print("# Song title: %s" % mod.name, file=fd)
    print("# Song author: %s" % mod.author, file=fd)
    print("#", file=fd)
    stype = {adpcm_a_sample: "adpcm_a", adpcm_b_sample: "adpcm_b"}
    for s in smp:
        print("- %s:" % stype[type(s)], file=fd)
        print("    name: %s" % s.name, file=fd)
        print("    # length: %d" % len(s.data), file=fd)
        print("    uri: data:;base64,%s" % base64.b64encode(s.data).decode(), file=fd)


def load_module(modname):
    with open(modname, "rb") as f:
        furzbin = f.read()
        furbin = zlib.decompress(furzbin)
        return binstream(furbin)


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description="Extract instruments and samples from a Furnace module")

    paction = parser.add_argument_group("action")
    pmode = paction.add_mutually_exclusive_group(required=True)
    pmode.add_argument("-i", "--instruments", action="store_const",
                       const="instruments", dest="action",
                       help="extract instrument information from a Furnace module")
    pmode.add_argument("-s", "--samples", action="store_const",
                       const="samples", dest="action", default="instruments",
                       help="extract samples data from a Furnace module")

    parser.add_argument("FILE", help="Furnace module")
    parser.add_argument("-o", "--output", help="Output file name")

    parser.add_argument("-n", "--name",
                        help="Name of the generated instrument table")

    parser.add_argument("-m", "--map",
                        help="Name of the ADPCM sample map file to include")

    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                        default=False, help="print details of processing")

    arguments = parser.parse_args()
    VERBOSE = arguments.verbose

    # load all samples data in memory from the map file
    bs = load_module(arguments.FILE)
    m = read_module(bs)
    smp = read_samples(m.samples, bs)
    ins = read_instruments(m.instruments, smp, bs)

    if arguments.output:
        outfd = open(arguments.output, "w")
    else:
        outfd = sys.__stdout__

    if arguments.name:
        name = arguments.name
    else:
        name = "nss_instruments"

    if arguments.map:
        sample_map = arguments.map
    else:
        sample_map = "samples.inc"

    if arguments.action == "instruments":
        generate_instruments(m, sample_map, name, ins, outfd)
    elif arguments.action == "samples":
        generate_sample_map(m, smp, outfd)
    else:
        error("Unknown action: %s" % arguments.action)


if __name__ == "__main__":
    main()
