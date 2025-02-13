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
from struct import pack, unpack, unpack_from
from adpcmtool import ym2610_adpcma, ym2610_adpcmb
from copy import deepcopy
from functools import reduce
from operator import ior

VERBOSE = False


def error(s):
    sys.exit("error: " + s)


def warning(s):
    dbg("warning: " + s)


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

    def s4(self):
        res = unpack_from("<i", self.data, self.pos)[0]
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
    speeds: list[int] = field(default_factory=list)
    arpeggio: int = 0
    frequency: float = 0.0
    fxcolumns: list[int] = field(default_factory=list)
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
    bs.read(4) # skip size
    bs.u1() # skip timebase
    bs.u1() # skip speed 1, use info from speed patterns later
    bs.u1() # skip speed 2, use info from speed patterns later
    mod.arpeggio = bs.u1()
    mod.frequency = bs.uf4()
    pattern_len = bs.u2()
    nb_orders = bs.u2()
    bs.read(2)  # skip highlights
    nb_instruments = bs.u2()
    nb_wavetables = bs.u2()
    nb_samples = bs.u2()
    nb_patterns = bs.u4()  # skip global pattern count
    chips = [x for x in bs.read(32)]
    assert chips[:chips.index(0)] == [165]  # single ym2610 chip
    bs.read(32 + 32 + 128)  # skip chips vol, pan, flags
    mod.name = bs.ustr()
    mod.author = bs.ustr()
    mod.pattern_len = pattern_len
    bs.uf4()  # skip tuning
    bs.read(20)  # skip furnace configs
    mod.instruments = [bs.u4() for i in range(nb_instruments)]
    _ = [bs.u4() for i in range(nb_wavetables)]
    mod.samples = [bs.u4() for i in range(nb_samples)]
    mod.patterns = [bs.u4() for i in range(nb_patterns)]
    # 14 tracks in ym2610 (4 FM, 3 SSG, 6 ADPCM-A, 1 ADPCM-B)
    mod.orders = [[-1 for x in range(14)] for y in range(nb_orders)]
    for i in range(14):
        for o in range(nb_orders):
            mod.orders[o][i] = bs.u1()
    mod.fxcolumns = [bs.u1() for x in range(14)]
    bs.read(14) # skip channel hide status (UI)
    bs.read(14) # skip channel collapse status (UI)
    for i in range(14): bs.ustr() # skip channel names
    for i in range(14): bs.ustr() # skip channel short names
    mod.comment = bs.ustr()
    bs.uf4() # skip master volume
    bs.read(28) # skip extended compatibity flags
    bs.u2() # skip virtual tempo numerator
    bs.u2() # skip virtual tempo denominator
    # right now, subsongs are not supported
    subsong_name = bs.ustr()
    subsong_comment = bs.ustr()
    subsongs = bs.u1()
    assert subsongs == 0, "subsongs in a single Furnace file is unsupported"
    bs.read(3) # skip reserved
    # song's additional metadata
    system_name = bs.ustr()
    game_name = bs.ustr()
    song_name_jp = bs.ustr()
    song_author_jp = bs.ustr()
    system_name_jp = bs.ustr()
    game_name_jp = bs.ustr()
    bs.read(12) # skip 1 "extra chip output setting"
    # patchbay
    bs.read(4*bs.u4()) # skip information
    bs.u1() # skip auto patchbay
    # more compat flags
    bs.read(8) # skip compat flags
    # speed pattern data
    speed_length = bs.u1()
    assert 1 <= speed_length <= 16
    mod.speeds = [bs.u1() for i in range(speed_length)]
    # TODO: grove patterns
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
    frequency: int = 0


@dataclass
class pcm_sample:
    name: str = ""
    data: bytearray = field(default=b"", repr=False)
    frequency: int = 0
    loop: bool = False


@dataclass
class fm_instrument:
    name: str = ""
    algorithm: int = 0
    feedback: int = 0
    am_sense: int = 0
    fm_sense: int = 0
    ops: list[fm_operator] = field(default_factory=list)


@dataclass
class ssg_macro:
    name: str = ""
    prog: list[int] = field(default_factory=list)
    keys: list[int] = field(default_factory=list)
    offset: list[int] = field(default_factory=list)
    bits: list[int] = field(default_factory=list)
    loop: int = 255
    autoenv: bool = False


@dataclass
class adpcm_a_instrument:
    name: str = ""
    sample: adpcm_a_sample = None


@dataclass
class adpcm_b_instrument:
    name: str = ""
    sample: adpcm_b_sample = None
    tuned: int = 0
    loop: bool = False


def read_fm_instrument(bs):
    ifm = fm_instrument()
    assert bs.u1() == 0xf4  # data for all operators
    ifm.algorithm, ifm.feedback = ubits(bs.u1(), [6, 4], [2, 0])
    ifm.am_sense, ifm.fm_sense = ubits(bs.u1(), [4, 3], [2, 0])
    bs.u1()  # unused
    for _ in range(4):
        op = fm_operator()
        tmpdetune, op.multiply = ubits(bs.u1(), [6, 4], [3, 0])
        # convert furnace detune format into ym2610 format
        tmpdetune-=3
        if tmpdetune<0:
            tmpdetune=abs(tmpdetune)+0b100
        op.detune=tmpdetune
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


def read_macro_data(length, bs):
    macros={}
    max_pos = bs.pos + length
    header_len = bs.u2()
    # TODO: we only support a single loop per macro as all the data are inlined
    # into a single sequence. This way, we simplify memory management at the expense
    # of a incomplete macro implementation.
    macro_loop = 255
    while bs.pos < max_pos:
        header_start = bs.pos
        # macro code (vol, arp, pitch...)
        code = bs.u1()
        if code == 255:
            break
        length = bs.u1()
        # loop step. 255 == no loop
        loop = bs.u1()
        # NOTE: due to how the instruments are edited in the Furnace UI, sometimes
        # the loop info stays in the module even if it's no longer in sync with
        # the current data length. Double check the flag before keeping it.
        if loop != 255 and loop<length:
            macro_loop = loop
        # unsupported. if loop is enabled, loop until the end
        release = bs.u1()
        # TODO meaning?
        mode = bs.u1()
        msize, mtype = ubits(bs.u1(), [7, 6], [2, 1])
        assert msize == 0, "macro value should be of type '8-bit unsigned'"
        assert mtype == 0, "macro should be of type 'sequence'. ADSR or LFO unsupported"
        # TODO unsupported. no delay
        delay = bs.u1()
        # TODO unsupported. same speed as the module tick
        speed = bs.u1()
        header_end = bs.pos
        assert header_end - header_start == header_len
        data = [bs.u1() for i in range(length)]
        macros[code]=data
    assert bs.pos == max_pos
    return macros, macro_loop


def configure_b_macros(ins, macros):
    # temporary workaround for instrument manually tuned with arpeggio macro
    if 1 in macros and len(macros[1])==1:
        ins.tuned = macros[1][0]
    else:
        error("unsupported use of macros in ADPCM-B instrument %s"%ins.name)


@dataclass
class ssg_prop:
    name: str = ""
    offset: int = 0


def read_ssg_macro(length, bs):
    # TODO -1 are unsupported in nullsound
    # name taken from Furnace's newIns.md and UI entries
    code_name = ["vol",
                 "arp",
                 "noiseFreq",
                 "wave",
                 "pitch",
                 "phaseReset",
                 "env",
                 "num",
                 "den"
                 ]
    code_offset = {"vol": 3,
                   "wave": 4,
                   "env": 0,
                   "arp": 5,
                   # "num": 1,
                   # "den": 2
                   }

    code_load_bit = {"vol": 1<<4, # BIT_LOAD_VOL
                     "wave": 1<<3, # BIT_LOAD_WAVEFORM
                     "env": 1<<5, # BIT_LOAD_REGS
                     "noiseFreq": 1<<5, # BIT_LOAD_REGS
                     "arp": 1<<2, # BIT_LOAD_NOTE
                     }

    autoenv=False
    blocks = {}
    macros, loop = read_macro_data(length, bs)
    for code in macros:
        blocks[code_name[code]] = macros[code]

    # pass: merge waveform sequence into vol & noise_tone sequences for SSG registers
    if "wave" in blocks:
        for i, wav in enumerate(blocks["wave"]):
            env, noise, tone = ubits(wav,[2,2],[1,1],[0,0]) # valid with furnace > dev213
            # pass: store envelope bit as mode for volume register
            if "vol" in blocks and i < len(blocks["vol"]):
                new_vol = (env<<4) | (blocks["vol"][i])
                blocks["vol"][i] = new_vol
            new_wav=(noise<<3|tone)^0xff
            blocks["wave"][i]=new_wav

    # pass: put auto-env information aside, it requires muls and divs
    # and we don't want to do that at runtime on the Z80. Instead
    # we simulate that feature via a specific NSS opcode
    if "num" in blocks or "den" in blocks:
        # NOTE: only read a single element as we don't allow
        # sequence on these registers right now
        num = blocks.get("num",[1])[0]
        den = blocks.get("den",[1])[0]
        autoenv=(num,den)
        blocks.pop("num", None)
        blocks.pop("den", None)

    # pass: compute load bits for all the macro steps
    # macrolen = max([len(blocks[k]) for k in keys])
    maxlen = max([len(blocks[k]) for k in blocks.keys()])
    bitblocks = {}
    # get the load bit for each key at every step
    for k in blocks.keys():
        listbit = [code_load_bit[k] for _ in range(len(blocks[k]))]
        listbit.extend([0 for _ in range(maxlen-len(blocks[k]))])
        bitblocks[k] = listbit
    # add BIT_EVAL_MACRO for every step (set last step only when looping)
    bitblocks['_'] = [1<<1]*maxlen
    if loop == 255:
        bitblocks['_'][-1] = 0
    # merge all the load bits for every step
    mergedbits = [reduce(ior,l) for l in zip(*bitblocks.values())]

    # pass: convert Furnace keys to NSS offsets
    tmpblocks={}
    for k in blocks.keys():
        if k not in code_offset:
            warning("macro element not supported yet: %02x"%code)
        else:
            tmpblocks[code_offset[k]]=blocks[k]
    blocks=tmpblocks

    # pass: build macro program
    prog = []
    realblocks=blocks
    blocks=deepcopy(realblocks)
    keys = sorted(list(blocks.keys()))
    seq, offset = compile_macro_sequence(keys, blocks, mergedbits)
    prog = []
    prog.extend(seq)
    prog.append(255)
    issg = ssg_macro(prog=prog, keys=keys, offset=offset, bits=mergedbits, loop=loop, autoenv=autoenv)
    return issg


def compile_macro_sequence(keys, blocks, loadbits):
    # offset for load function
    offset = [v if i==0 else keys[i]-keys[i-1]-1 for i,v in enumerate(keys)]

    # macro data: pad all blocks sizes
    longest_block = max([len(b) for b in blocks.values()])
    sentinel = 1024
    for k in blocks.keys():
        blocks[k].extend([sentinel]*(longest_block-len(blocks[k])))
    zipped = list(zip(*[blocks[k] for k in keys]))

    dbg("MACRO %s %s"%(keys, zipped))
    seq = []
    for steps in zipped:
        dbg("STEP  %s %s"%(keys, steps))
        off = 0
        for i, o in enumerate(keys):
            value = steps[i]
            dbg("[%02d] k:%d, i:%d v:%d"%(off, o, i, value))
            if value != sentinel:
                  macro_offset = o - off
                  dbg("    -> %d: %d"%(macro_offset, value))
                  seq.extend([macro_offset, value])
                  off = o+1
        seq.append(255)
    dbg("RESULT %s"%seq)

    return seq, offset


def read_instrument(nth, bs, smp):
    def asm_ident(x):
        return re.sub(r"\W|^(?=\d)", "_", x).lower()

    assert bs.read(4) == b"INS2"
    endblock = bs.pos + bs.u4()
    assert bs.u2() >= 127  # format version
    itype = bs.u2()
    assert itype in [1, 6, 37, 38]  # FM, SSG, ADPCM-A, ADPCM-B
    # for when the instrument has no SM feature
    sample = 0
    name = ""
    ins = None
    mac = None
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
        elif feat == b"MA" and itype == 6:
            # SSG macro is essentially the full SSG instrument
            mac = read_ssg_macro(length, bs)
        elif feat == b"MA" and itype == 38:
            # other macro types are currently not supported
            mac, _ = read_macro_data(length, bs)
        elif feat == b"NE":
            # NES DPCM tag is present when the instrument
            # uses a PCM sample instead of ADPCM. Skip it
            assert bs.u1()==0, "sample map unsupported"
        else:
            warning("unexpected feature in sample %02x%s: %s" % \
                    (nth, (" (%s)"%name if name else ""), feat.decode()))
            bs.read(length)
    # for ADPCM sample, populate sample data
    if itype in [37, 38]:
        ins = {37: adpcm_a_instrument,
               38: adpcm_b_instrument}[itype]()
        # ADPCM-B loop information
        if itype == 38:
            ins.loop = smp[sample].loop
        if isinstance(smp[sample],pcm_sample):
            # the sample is encoded in PCM, so it has to be converted
            # to be played back on the hardware.
            warning("sample '%s' is encoded in PCM, converting to ADPCM-%s"%\
                (smp[sample].name, "A" if itype==37 else "B"))
            converted = convert_sample(smp[sample], itype)
            smp[sample] = converted
        ins.sample = smp[sample]
    # generate a ASM name for the instrument or macro
    if itype == 6:
        mac.name = asm_ident("macro_%02x_%s"%(nth, name))
        mac.load_name = asm_ident("macro_%02x_load_func"%nth)
        mac.loop_name = asm_ident("macro_%02x_loop"%nth)
        return mac
    else:
        ins.name = asm_ident("instr_%02x_%s"%(nth, name))
        if itype == 38 and mac:
            configure_b_macros(ins, mac)
        return ins


def read_instruments(ptrs, smp, bs):
    ins = []
    n = 0
    for p in ptrs:
        bs.seek(p)
        ins.append(read_instrument(n, bs, smp))
        # print(ins[-1].name)
        n += 1
    return ins


def read_sample(prefix, bs, sample_idx):
    assert bs.read(4) == b"SMP2"
    _ = bs.u4()  # endblock
    name = bs.ustr()
    adpcm_samples = bs.u4()
    _ = bs.u4()  # unused compat frequency
    c4_freq = bs.u4()
    stype = bs.u1()
    if stype in [5,6]: # ADPCM-A, ADPCM-B
        assert adpcm_samples % 2 == 0
        data_bytes = adpcm_samples // 2
        data_padding = 0
        if data_bytes % 256 != 0:
            dbg("length of sample '%s' (%d bytes) is not a multiple of 256bytes, padding added"%\
                (str(name), data_bytes))
            data_padding = (((data_bytes+255)//256)*256) - data_bytes
    elif stype == 16: # PCM16 (requires conversion to ADPCM)
        data_bytes = adpcm_samples * 2
        data_padding = 0  # adpcmtool codecs automatically adds padding
    else:
        error("sample '%s' is of unsupported type: %d"%(str(name), stype))
    bs.u1()  # unused loop direction
    bs.u2()  # unused flags
    loop_start, loop_end = bs.s4(), bs.s4()
    bs.read(16)  # unused rom allocation
    data = bs.read(data_bytes) + bytearray(data_padding)
    # generate a ASM name for the instrument
    insname = "%s_%02x_%s"%(prefix, sample_idx, re.sub(r"\W|^(?=\d)", "_", name).lower())
    ins = {5: adpcm_a_sample,
           6: adpcm_b_sample,
           16: pcm_sample}[stype](insname, data)
    ins.loop = loop_start != -1 and loop_end != -1
    ins.frequency = c4_freq
    return ins


def convert_sample(pcm_sample, totype):
    codec = {37: ym2610_adpcma,
             38: ym2610_adpcmb}[totype]()
    pcm16s = unpack('<%dh' % (len(pcm_sample.data)>>1), pcm_sample.data)
    adpcms=codec.encode(pcm16s)
    adpcms_packed = [(adpcms[i] << 4 | adpcms[i+1]) for i in range(0, len(adpcms), 2)]
    # convert sample to the right class
    converted = {37: adpcm_a_sample,
                 38: adpcm_b_sample}[totype](pcm_sample.name, bytes(adpcms_packed))
    converted.frequency = pcm_sample.frequency
    return converted


def module_id_from_path(p):
    f = os.path.splitext(os.path.basename(p))[0]
    return re.sub(r"\W|^(?=\d)", "_", f).lower()


def read_samples(name_prefix, ptrs, bs):
    smp = []
    for i, p in enumerate(ptrs):
        bs.seek(p)
        smp.append(read_sample(name_prefix, bs, i))
    return smp

def check_for_unused_samples(smp, bs):
    # module might have unused samples, leave them in the output
    # if these are pcm_samples, convert them to adpcm_a to avoid errors
    for i,s in enumerate(smp):
        if isinstance(s, pcm_sample):
            smp[i] = convert_sample(s, 37)

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
    print("        .db     0xff, 0xff, 0xff, 0xff   ; empty", file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; KS | AR" % ksar, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; AM | DR" % amdr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SR" % sr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SL | RR" % slrr, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; SSG" % ssgeg, file=fd)
    print("        .db     0x%02x                     ; FB | ALGO" % fbalgo, file=fd)
    print("        .db     0x%02x                     ; LR | AMS | FMS" % amsfms, file=fd)
    print("        .db     0x%02x, 0x%02x, 0x%02x, 0x%02x   ; TL" % tl, file=fd)
    print("", file=fd)


def asm_ssg_macro(mac, fd):
    prev = 0
    cur = mac.prog.index(255, 0)
    lines = []
    # split macro into list of steps
    while cur != prev:
        line = mac.prog[prev:cur+1]
        lines.append(", ".join(["0x%02x"%x for x in line]))
        prev = cur+1
        cur = mac.prog.index(255,cur+1)
    # there should be a load value for each line
    assert len(lines) == len(mac.bits)
    # macro actions
    print("%s:" % mac.name, file=fd)
    longest = max([len(x) for x in lines]) + len(", 0x..")
    step = 0
    print("        ;; macro load function", file=fd)
    print("        .dw     %s" % mac.load_name, file=fd)
    print("        ;; macro actions", file=fd)
    for l, b in zip(lines, mac.bits):
        fmtstep = ("%s, 0x%02x"%(l,b)).ljust(longest)
        if step==mac.loop:
            print("%s:" % mac.loop_name, file=fd)
        print("        .db     %s   ; tick %d"%(fmtstep, step), file=fd)
        step += 1
    print("        .db     %s   ; end"%"0xff".ljust(longest), file=fd)
    if mac.loop != 255:
        print("        .dw     %s   ; loop"%mac.loop_name.ljust(longest), file=fd)
    else:
        print("        .dw     %s   ; no loop"%"0x0000".ljust(longest), file=fd)
    print("", file=fd)
    # load func
    asm_ssg_load_func(mac, fd)


def asm_ssg_load_func(mac, fd):
    def asm_ssg(reg):
        print("        ld      b, #0x%02x"%reg, file=fd)
        print("        ld      c, (hl)", file=fd)
        print("        call    ym2610_write_port_a", file=fd)
    def asm_cha(reg):
        print("        set     4, (ix)", file=fd)
    def offset(off):
        if off==1:
            print("        inc     hl", file=fd)
        else:
            print("        ld      bc, #%d"%off, file=fd)
            print("        add     hl, bc", file=fd)
        pass
    ssg_map = {
        0: 0x0d, # REG_SSG_ENV_SHAPE
        1: 0x0b, # REG_SSG_ENV_FINE_TUNE
        2: 0x0c, # REG_SSG_ENV_COARSE_TUNE
    }
    cha_map = {
        3: 0x08  # REG_SSG_A_VOLUME
    }
    other_keys = [
        5  # arpeggio - LOAD_REG
    ]

    # the load function only take care of generic registers
    # filter out the other registers in the macro (waveform, note)
    gen_off = []
    gen_keys = []
    prev_off = 0
    for o,k in zip(mac.offset, mac.keys):
        if k in [0, 4]:
            prev_off += 1
            continue
        gen_off.append(o+prev_off)
        gen_keys.append(k)

    print("%s:" % mac.load_name, file=fd)
    data = zip(range(len(mac.offset)), gen_off, gen_keys)
    for i, o, k in data:
        if i != 0:
            o+=1
        offset(o)
        if k in ssg_map:
            asm_ssg(ssg_map[k])
        elif k in cha_map:
            asm_cha(cha_map[k])
        elif k in other_keys:
            pass
        else:
            error("no ASM for SSG property: %d"%k)
    print("        ret", file=fd)
    print("", file=fd)


def asm_adpcm_instrument(ins, fd):
    name = ins.sample.name.upper()
    print("%s:" % ins.name, file=fd)
    print("        .db     %s_START_LSB, %s_START_MSB  ; start >> 8" % (name, name), file=fd)
    print("        .db     %s_STOP_LSB,  %s_STOP_MSB   ; stop  >> 8" % (name, name), file=fd)
    if isinstance(ins, adpcm_b_instrument):
        print("        .db     0x%02x  ; loop" % (ins.loop,), file=fd)
    print("", file=fd)


def generate_instruments(mod, sample_map_name, ins_name, bank, ins, fd):
    print(";;; NSS instruments and macros", file=fd)
    print(";;; generated by furtool.py (ngdevkit)", file=fd)
    print(";;; ---", file=fd)
    print(";;; Song title: %s" % mod.name, file=fd)
    print(";;; Song author: %s" % mod.author, file=fd)
    print(";;;", file=fd)
    print("", file=fd)
    if bank != None:
        print("        .area   BANK%d"%bank, file=fd)
    else:
        print("        .area   CODE", file=fd)
    print("", file=fd)
    print("        ;; offset of ADPCM samples in ROMs", file=fd)
    print('        .include "%s"' % sample_map_name, file=fd)
    print("", file=fd)
    inspp = {fm_instrument: asm_fm_instrument,
             ssg_macro: asm_ssg_macro,
             adpcm_a_instrument: asm_adpcm_instrument,
             adpcm_b_instrument: asm_adpcm_instrument}
    if ins:
        print("%s::" % ins_name, file=fd)
        for i in ins:
            print("        .dw     %s" % i.name, file=fd)
    else:
        print(";; no instruments defined in this song", file=fd)
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


def samples_from_module(modname):
    bs = load_module(modname)
    m = read_module(bs)
    smp = read_samples(module_id_from_path(modname), m.samples, bs)
    ins = read_instruments(m.instruments, smp, bs)
    check_for_unused_samples(smp, bs)
    return smp


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

    parser.add_argument("-b", "--bank", type=int,
                       help="generate data for a bank-switched Z80 memory area")

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
    smp = read_samples(module_id_from_path(arguments.FILE), m.samples, bs)
    ins = read_instruments(m.instruments, smp, bs)
    check_for_unused_samples(smp, bs)

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

    bank = arguments.bank

    if arguments.action == "instruments":
        generate_instruments(m, sample_map, name, bank, ins, outfd)
    elif arguments.action == "samples":
        generate_sample_map(m, smp, outfd)
    else:
        error("Unknown action: %s" % arguments.action)


if __name__ == "__main__":
    main()
