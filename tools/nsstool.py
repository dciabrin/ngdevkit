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

"""furtool.py - convert Furnace module patterns to NSS stream."""

import argparse
import base64
import re
import sys
import zlib
from dataclasses import dataclass, field, astuple, make_dataclass
from struct import pack, unpack_from
from furtool import binstream, load_module, read_module, read_samples, read_instruments

VERBOSE = False


def error(s):
    sys.exit("error: " + s)


def dbg(s):
    if VERBOSE:
        print(s, file=sys.stderr)



@dataclass
class fur_pattern:
    """Notes and effects for one channel of a particular pattern in the song"""
    channel: int = 0
    index: int = 0
    rows: list = field(default_factory=list, repr=False)

@dataclass
class fur_row:
    """A single note with common attributes and effects"""
    note: int = -1
    ins: int = -1
    vol: int = -1
    fx: list[int, int] = field(default_factory=list)



#
# Helper functions
#

def empty_row(fxcols):
    return fur_row(-1, -1, -1, [(-1,-1)]*fxcols)


def is_empty(r):
    return r.note==-1 and r.ins==-1 and r.vol==-1 and all([f==-1 for f,v in r.fx])


def to_nss_note(furnace_note):
    octave = (furnace_note // 12) - 5
    note = furnace_note % 12
    nss_note = (octave << 4) + note
    return nss_note

def make_ssg_note(furnace_note):
    octave = (furnace_note // 12) - 5
    note = furnace_note % 12
    nss_note = (octave << 4) + note
    return s_note(nss_note)


def dbg_row(r, cols):
    semitones = [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
    if r.note == -1:
        notestr = "..."
    elif r.note == 180:
        notestr = "OFF"
    else:
        octave=r.note//12 - 5
        semitone=r.note%12
        notestr = "%s%s"%(semitones[semitone].ljust(2,"-"), octave)

    insstr = "%02x"%r.ins if r.ins != -1 else ".."
    volstr = "%02x"%r.ins if r.vol != -1 else ".."

    fxstr=""
    for f,v in r.fx[:cols]:
        sf = "%02x" % f if f!=-1 else ".."
        sv = "%02x" % v if v!=-1 else ".."
        fxstr += " %s%s" % (sf, sv)
    print("%s %s %s%s"%(notestr,insstr,volstr,fxstr))

    
def dbg_pattern(p, m):
    cols = m.fxcolumns[p.channel]
    for r in p.rows:
        dbg_row(r, cols)

        

#
# Furnace parsers
#    

def read_pattern(m, bs):
    assert bs.read(4) == b"PATN"
    end_patn_pos = bs.u4() + bs.pos
    bs.u1() # unused subsong
    channel = bs.u1()
    index = bs.u2()
    bs.ustr() # unused name
    fxcols = m.fxcolumns[channel]
    all_rows = []
    while (bs.pos < end_patn_pos):
        # each row comes with a bitfield descriptor encoding the presence
        # of optional row data (note, instrument, volume, effects...)
        desc = bs.u1()
        if desc == 0xff:
            # no more row to read in this pattern
            continue
        if desc & 0b10000000:
            # the next 2+n rows and empty
            empty = 2 + (desc & 0b01111111)
            all_rows.extend([empty_row(fxcols)] * empty)
            continue
        else:
            # desc contains bits for data present for this row
            # 7 |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
            # _ | fx7-4 | fx3-0 |fx0 val|  fx0  |  vol  |  ins  | note  |
            row=empty_row(fxcols)

            # effects and associated values, up to 8
            fxdesc = (desc & 0b11000) >> 3
            if desc & 0b100000:
                # descriptor for fx3..fx0 present
                fxdesc |= bs.u1()
            if desc & 0b1000000:
                # descriptor for fx7..fx4 present
                fxdesc |= bs.u1() << 8

            # common attributes: note, instrument, volume
            if desc & 0b001:
                row.note=bs.u1()
            if desc & 0b010:
                row.ins=bs.u1()
            if desc & 0b100:
                row.vol=bs.u1()

            # read all available fx data (fx and vals)
            fxdata = [-1] * 16
            for f in range(0, 16):
                if fxdesc & (1<<f):
                    fxdata[f] = bs.u1()
                else:
                    fxdata[f] = -1
            # group data into (fx,val) tuples
            fxvals = [(fxdata[n], fxdata[n+1]) for n in range(0, len(fxdata), 2)]
            # only keep the number of configured effects for that column
            row.fx = fxvals[:m.fxcolumns[channel]]
            all_rows.append(row)
    assert desc == 0xff
    # no more data for this pattern, the remaining rows are empty
    remainder = m.pattern_len - len(all_rows)
    all_rows.extend([empty_row(fxcols)] * remainder)
    return fur_pattern(channel, index, all_rows)


def read_all_patterns(m, bs):
    """read all the unique patterns in the Furnace song"""
    patterns = {}
    for p in m.patterns:
        bs.seek(p)
        p = read_pattern(m, bs)
        patterns[(p.index,p.channel)]=p
    return patterns



#
# NSS opcodes
#

def register_nss_ops():
    nss_opcodes = (
        # 0x00
        None,
        None,
        ("nss_loop", ["lsb", "msb"]),
        ("nss_end", ),
        ("timer_b" , ["val"]),
        ("wait_b"  , ["val"]),
        None,
        None,
        # 0x08
        None,
        None,
        None,
        None,
        ("b_instr" , ["inst"]),
        ("b_note"  , ["note"]),
        ("b_stop"  , ),
        ("fm_ctx_1", ),
        # 0x10
        ("fm_ctx_2", ),
        ("fm_ctx_3", ),
        ("fm_ctx_4", ),
        ("fm_instr", ["inst"]),
        ("fm_note" , ["note"]),
        ("fm_stop" , ),
        ("a_ctx_1" , ),
        ("a_ctx_2" , ),
        # 0x18
        ("a_ctx_3" , ),
        ("a_ctx_4" , ),
        ("a_ctx_5" , ),
        ("a_ctx_6" , ),
        ("a_instr" , ["inst"]),
        ("a_start" , ),
        ("a_stop"  , ),
        ("op1_lvl" , ["level"]),
        # 0x20
        ("op2_lvl" , ["level"]),
        ("op3_lvl" , ["level"]),
        ("op4_lvl" , ["level"]),
        ("fm_pitch", ["tune"]),
        ("s_ctx_1" , ),
        ("s_ctx_2" , ),
        ("s_ctx_3" , ),
        ("s_macro" , ["macro"]),
        # 0x28
        ("s_note"  , ["note"]),
        ("s_stop"  , ),
        ("s_vol"   , ["volume"]),
        ("fm_vol"  , ["volume"]),
        ("s_env"   , ["fine", "coarse"]),
        ("s_vibrato", ["speed_depth"]),
        ("s_slide_u", ["speed_depth"]),
        ("s_slide_d", ["speed_depth"]),
        # reserved opcodes
        ("nss_label", ["pat"])
    )
    for opcode, op in enumerate(nss_opcodes):
        if op:
            cname=op[0]
            cid=("_opcode",int,field(default=opcode,repr=False))
            args=op[1] if len(op)>1 else []
            fields=[(x, int) for x in args]+[cid]
            globals()[cname]=make_dataclass(cname, fields)



#
# Furnace module conversion functions
#
def convert_fm_row(row, channel, opcodes): 
    ctx_t = {0: fm_ctx_1, 1: fm_ctx_2, 2: fm_ctx_3, 3: fm_ctx_4}
    jmp_to_order = -1
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # volume (must be in the NSS stream before instrument)
        if row.vol != -1:
            opcodes.append(fm_vol(row.vol))
        # instrument
        if row.ins != -1:
            opcodes.append(fm_instr(row.ins))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x12:  # OP1 level
                opcodes.append(op1_lvl(fxval))
            elif fx == 0x13:  # OP2 level
                opcodes.append(op2_lvl(fxval))
            elif fx == 0x14:  # OP3 level
                opcodes.append(op3_lvl(fxval))
            elif fx == 0x15:  # OP4 level
                opcodes.append(op4_lvl(fxval))
            elif fx == 0xe5:  # pitch
                opcodes.append(fm_pitch((fxval-0x80)//3))
        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(fm_stop())
            else:
                opcodes.append(fm_note(to_nss_note(row.note)))
    return jmp_to_order


def convert_s_row(row, channel, opcodes): 
    ctx_t = {4: s_ctx_1, 5: s_ctx_2, 6: s_ctx_3}
    jmp_to_order = -1
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # instrument
        if row.ins != -1:
            opcodes.append(s_macro(row.ins))
        # volume
        if row.vol != -1:
            opcodes.append(s_vol(row.vol))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x04:  # vibrato
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(s_vibrato(fxval))
            elif fx == 0xe1:  # slide up
                assert fxval != -1
                opcodes.append(s_slide_u(fxval))
            elif fx == 0xe2:  # slide down
                assert fxval != -1
                opcodes.append(s_slide_d(fxval))

        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(s_stop())
            else:
                opcodes.append(make_ssg_note(row.note))
    return jmp_to_order


def convert_a_row(row, channel, opcodes): 
    ctx_t = {7: a_ctx_1, 8: a_ctx_2, 9: a_ctx_3, 10: a_ctx_4, 11: a_ctx_5, 12: a_ctx_6}
    jmp_to_order = -1
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # instrument
        if row.ins != -1:
            opcodes.append(a_instr(row.ins))
        # TODO volume
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(a_stop())
            else:
                opcodes.append(a_start())
    return jmp_to_order


def convert_b_row(row, channel, opcodes): 
    jmp_to_order = -1
    if not is_empty(row):
        # instrument
        if row.ins != -1:
            opcodes.append(b_instr(row.ins))
        # TODO volume
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(b_stop())
            else:
                opcodes.append(b_note(to_nss_note(row.note)))
    return jmp_to_order


def raw_nss(m, p, bs, channels):
    # unoptimized nss opcodes generated from the Furnace song
    nss = []
    
    # channels to consider for conversion
    chlist = [int(c, 16) for c in sorted(list(channels.lower()))]
    f_channels = list(filter(lambda x: 0 <= x <= 3, chlist))
    s_channels = list(filter(lambda x: 4 <= x <= 6, chlist))
    a_channels = list(filter(lambda x: 7 <= x <= 12, chlist))
    b_channel = list(filter(lambda x: x == 13, chlist))

    # initialize stream speed from module 
    tick = m.speed
    tb = round(256 - (4000000 / (1152 * m.frequency)))
    nss.append(timer_b(tb))

    # -- structures
    # a song is composed of a sequence of orders
    # an order is just a group of 14 patterns (4 FM, 3 SSG, 6 ADPCM-A, 1 ADPCM-B)

    # -- playback
    # playing a song consists in playing every order one after the other
    # and potentially looping back when there is no more order to play
    #
    # playing an order works by playing one row of each of its pattern, then
    # playing the next row... when all rows are played, playback continues
    # to the next order in the song
    #
    # during playback, a row can request to jump (continue playback) to
    # the beginning of another order, for example to avoid playing the
    # remaining rows of an order. any jump to a previously played order
    # is essentially equivalent to looping the song playback.
    
    seen_orders=[]
    order=0

    while order < len(m.orders) and order not in seen_orders:
        # recall we've processed this order and set its location in the stream
        seen_orders.append(order)
        nss.append(nss_label(order))

        #  -1: no jump required after row processed
        #   n: jump to order n for the next row to play
        # 256: jump to the next order for the next row to play
        # 257: jump outside the stream (i.e. stop)
        jmp_to_order = -1

        order_patterns = [p[(m.orders[order][f],f)] for f in range(14)]

        # all channels should have the same number of rows
        pattern_length = len(order_patterns[0].rows)
        assert len(set([len(p.rows) for p in order_patterns])) == 1
        assert pattern_length == m.pattern_len

        for index in range(pattern_length):
            # nss opcodes to add at the end of each processed Furnace row
            opcodes = []

            # FM channels
            for channel in f_channels:
                row = order_patterns[channel].rows[index]
                j = convert_fm_row(row, channel, opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # SSG channels
            for channel in s_channels:
                row = order_patterns[channel].rows[index]
                j = convert_s_row(row, channel, opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # ADPCM-A channels
            for channel in a_channels:
                row = order_patterns[channel].rows[index]
                j = convert_a_row(row, channel, opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # ADPCM-B channel
            for channel in b_channel:
                row = order_patterns[channel].rows[index]
                j = convert_b_row(row, channel, opcodes)
                jmp_to_order = max(jmp_to_order, j)

            # all channels are processed for this pos.
            # add all generated opcodes plus a time sync
            nss.extend(opcodes)
            nss.append(wait_b(tick))
            
            # stop processing further rows if a JMP fx was used
            if jmp_to_order != -1:
                break
            
        if 0 <= jmp_to_order < 256:
            order = jmp_to_order
        else:
            order += 1

    if order in seen_orders:
        # the last order was already processed, the stream will loop
        nloop = nss_loop(-1, -1)
        nloop.pat=order
        nss.append(nloop)
    else:
        # orders were processed in sequence, the stream will end
        nss.append(nss_end())
    return nss


#
# NSS optimization passes
#

def compact_wait_b(nss):
    compact = []
    wait = 0
    for op in nss:
        if type(op) == wait_b:
            wait += op.val
            # the wait opcode cannot encode more than 255 ticks
            if wait>255:
                new_wait = wait_b(255)
                compact.append(new_wait)
                wait -= 255
        else:
            if wait>0:
                new_wait = wait_b(wait)
                compact.append(new_wait)
                wait=0
            compact.append(op)
    return compact


def compact_instr(nss):
    out = []
    fm_ctx_map = {fm_ctx_1: 0, fm_ctx_2: 1, fm_ctx_3: 2, fm_ctx_4: 3}
    fm_ctx = 0
    s_ctx_map = {s_ctx_1: 0, s_ctx_2: 1, s_ctx_3: 2}
    s_ctx = 0
    a_ctx_map = {a_ctx_1: 0, a_ctx_2: 1, a_ctx_3: 2, a_ctx_4: 3, a_ctx_5: 4, a_ctx_6: 5}
    a_ctx = 0
    fm_is = [-1, -1, -1, -1]
    s_is = [-1, -1, -1]
    a_is = [-1, -1, -1, -1, -1, -1]
    b_i = -1
    for op in nss:
        if type(op) == fm_instr:
            if fm_is[fm_ctx] != op.inst:
                fm_is[fm_ctx] = op.inst
                out.append(op)
        elif type(op) in fm_ctx_map.keys():
            fm_ctx = fm_ctx_map[type(op)]
            out.append(op)
        elif type(op) == s_macro:
            if s_is[s_ctx] != op.macro:
                s_is[s_ctx] = op.macro
                out.append(op)
        elif type(op) in s_ctx_map.keys():
            s_ctx = s_ctx_map[type(op)]
            out.append(op)
        elif type(op) == a_instr:
            if a_is[a_ctx] != op.inst:
                a_is[a_ctx] = op.inst
                out.append(op)
        elif type(op) in a_ctx_map.keys():
            a_ctx = a_ctx_map[type(op)]
            out.append(op)
        elif type(op) == b_instr:
            if b_i != op.inst:
                b_i = op.inst
                out.append(op)
        else:
            out.append(op)
    return out


def compact_ctx(nss):
    out = []
    fm_ctx_map = {fm_ctx_1: 0, fm_ctx_2: 1, fm_ctx_3: 2, fm_ctx_4: 3}
    s_ctx_map = {s_ctx_1: 0, s_ctx_2: 1, s_ctx_3: 2}
    a_ctx_map = {a_ctx_1: 0, a_ctx_2: 1, a_ctx_3: 2, a_ctx_4: 3, a_ctx_5: 4, a_ctx_6: 5}
    fm_ctx = 0
    s_ctx = 0
    a_ctx = 0
    for op in nss:
        if type(op) == wait_b:
            fm_ctx=0
            s_ctx=0
            a_ctx=0
        elif type(op) in [fm_note, fm_stop]:
            fm_ctx+=1
        elif type(op) in [s_note, s_stop]:
            s_ctx+=1
        elif type(op) in [a_start, a_stop]:
            a_ctx+=1
        elif type(op) in fm_ctx_map.keys():
            val = fm_ctx_map[type(op)]
            if fm_ctx == val: continue
            else: fm_ctx = val
        elif type(op) in s_ctx_map.keys():
            val = s_ctx_map[type(op)]
            if s_ctx == val: continue
            else: s_ctx = val
        elif type(op) in a_ctx_map.keys():
            val = a_ctx_map[type(op)]
            if a_ctx == val: continue
            else: a_ctx = val
        out.append(op)
    return out


def simulate_ssg_autoenv(nss, ins):
    semitones = [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
    freqs = [
        [  32.7 ,    34.65,    36.71,    38.89,   41.2 ,   43.65,   46.25,   49.0 ,   51.91,   55.0 ,   58.27,   61.74],
        [  65.41,    69.3 ,    73.42,    77.78,   82.41,   87.31,   92.5 ,   98.0 ,  103.8 ,  110.0 ,  116.5 ,  123.5 ],
        [ 130.8 ,   138.6 ,   146.8 ,   155.6 ,  164.8 ,  174.6 ,  185.0 ,  196.0 ,  207.7 ,  220.0 ,  233.1 ,  246.9 ],
        [ 261.6 ,   277.2 ,   293.7 ,   311.1 ,  329.6 ,  349.2 ,  370.0 ,  392.0 ,  415.3 ,  440.0 ,  466.2 ,  493.9 ],
        [ 523.3 ,   554.4 ,   587.3 ,   622.3 ,  659.3 ,  698.5 ,  740.0 ,  784.0 ,  830.6 ,  880.0 ,  932.3 ,  987.8 ],
        [1047.0 ,  1109.0 ,  1175.0 ,  1245.0 , 1319.0 , 1397.0 , 1480.0 , 1568.0 , 1661.0 , 1760.0 , 1865.0 , 1976.0 ],
        [2093.0 ,  2217.0 ,  2349.0 ,  2489.0 , 2637.0 , 2794.0 , 2960.0 , 3136.0 , 3322.0 , 3520.0 , 3729.0 , 3951.0 ],
        [4186.0 ,  4435.0 ,  4699.0 ,  4978.0 , 5274.0 , 5588.0 , 5920.0 , 6272.0 , 6645.0 , 7040.0 , 7459.0 , 7902.0 ]
    ]
    out = []
    s_ctx_map = {s_ctx_1: 0, s_ctx_2: 1, s_ctx_3: 2}
    s_ctx = 0
    s_is = [-1, -1, -1]
    s_autoenv = [False, False, False]
    s_period = [-1, -1, -1]
    for op in nss:
        if type(op) == wait_b:
            s_ctx=0
            out.append(op)
        elif type(op) == s_macro:
            if s_is[s_ctx] != op.macro:
                s_is[s_ctx] = op.macro
                # False if autoenv isn't defined
                s_autoenv[s_ctx]=ins[op.macro].autoenv
                s_period[s_ctx]=-1
                out.append(op)
        elif type(op) in s_ctx_map.keys():
            s_ctx = s_ctx_map[type(op)]
            out.append(op)
        elif type(op) == s_note:
            autoenv=s_autoenv[s_ctx]
            if autoenv:
                o=(op.note>>4)&0xf
                n=op.note&0xf
                notefreq = int(freqs[o-1][n])
                num, den = autoenv
                period = ((125000//notefreq)*den//num)//16
                # only generate a s_env opcode if the last
                # note played on this channel differred
                if s_period[s_ctx] != period:
                    s_period[s_ctx] = period
                    fine, coarse = period&0xff, (period>>8)&0xff
                    out.append(s_env(fine, coarse))
            s_ctx+=1
            out.append(op)
        elif type(op) == s_stop:
            s_ctx+=1
            out.append(op)
        else:
            out.append(op)
    return out


def remove_unreferenced_labels(nss):
    if isinstance(nss[-1], nss_loop):
        order = nss[-1].pat
    else:
        order = -1
    out=[]
    for op in nss:
        if isinstance(op, nss_label) and op.pat != order:
            continue
        else:
            out.append(op)
    return out


def compute_loop_offset(nss):
    if len(nss)==0 or not isinstance(nss[-1], nss_loop):
        return nss
    # when this pass is executed, there should be a single label in the nss
    assert len(list(filter(lambda x: isinstance(x, nss_label), nss))) == 1
    out = []
    offset = 0
    label_offset = -1

    for op in nss:
        if isinstance(op, nss_label):
            label_offset = offset
        else:
            # 1 byte for opcode, + 1 byte per args, - 1 byte for _opcode arg)
            offset += 1+len(astuple(op))-1
            out.append(op)
    out[-1].lsb = label_offset & 0xff
    out[-1].msb = (label_offset>>8) & 0xff
    return out


def nss_to_asm(nss, m, name, fd):
    size = sum([len(astuple(op))-1+1 for op in nss])
    print(";;; NSS music data", file=fd)
    print(";;; generated by nsstool.py (ngdevkit)", file=fd)
    print(";;; ---", file=fd)
    print(";;; Song title: %s" % m.name, file=fd)
    print(";;; Song author: %s" % m.author, file=fd)
    print(";;; NSS size: %d"%size, file=fd)
    print(";;;", file=fd)
    print("", file=fd)
    print("        .area   CODE", file=fd)
    print("", file=fd)
    if name:
        print("%s::" % name, file=fd)
    for op in nss:
        opcode = [op._opcode]
        # remove the last _opcode field, it's just a metadata
        args = list(astuple(op)[:-1])
        hexdata = ", ".join(["0x%02x"%(x&0xff,) for x in opcode+args])
        comment = " ; %s"%type(op).__name__.upper()
        print("        .db     "+hexdata.ljust(24)+comment, file=fd)


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description="Convert Furnace module patterns to NSS stream")

    parser.add_argument("FILE", help="Furnace module")
    parser.add_argument("-o", "--output", help="Output file name")

    parser.add_argument("-n", "--name",
                        help="Name of the ASM label for the NSS data. Empty name skips label.")

    parser.add_argument("-c", "--channels", help="Process specific channels. One hex digit per channel", default='0123456789abcd')

    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
                        default=False, help="print details of processing")

    arguments = parser.parse_args()
    VERBOSE = arguments.verbose

    if arguments.output:
        outfd = open(arguments.output, "w")
    else:
        outfd = sys.__stdout__

    if arguments.name != None:
        name = arguments.name
    else:
        name = "nss_stream"

    # validate channel filtering option
    if not all(['0' <= c <= 'd' for c in arguments.channels.lower()]):
        error("invalid channel filter")

    register_nss_ops()

    dbg("Loading Furnace module %s"%arguments.FILE)
    bs = load_module(arguments.FILE)
    m = read_module(bs)
    smp = read_samples(m.samples, bs)
    ins = read_instruments(m.instruments, smp, bs)
    p = read_all_patterns(m, bs)
    
    dbg("Convert Furnace patterns to unoptimized sequence of NSS opcodes")
    nss = raw_nss(m, p, bs, arguments.channels)
    
    dbg("Transformation passes:")
    dbg(" - remove unreference NSS labels")
    nss = remove_unreferenced_labels(nss)

    dbg(" - merge adjacent WAIT_B opcodes")
    nss = compact_wait_b(nss)

    dbg(" - remove successive INSTR opcodes if they keep intrument unchanged")
    nss = compact_instr(nss)

    dbg(" - remove CTX opcodes if they keep the current context unchanged")
    nss = compact_ctx(nss)

    dbg(" - look for SSG autoenv macros and insert opcodes to simulate them")
    nss = simulate_ssg_autoenv(nss, ins)

    dbg(" - compute label offset when LOOP opcode is used")
    nss = compute_loop_offset(nss)

    nss_to_asm(nss, m, name, outfd)


if __name__ == "__main__":
    main()
