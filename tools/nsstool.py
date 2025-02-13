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
from furtool import binstream, load_module, read_module, read_samples, read_instruments, module_id_from_path

VERBOSE = False


def error(s):
    sys.exit("error: " + s)

def warn(s):
    print("WARNING: %s"%s, file=sys.stderr)

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
    # we count octave from C-0 (furnace starts from C--5)
    nss_note = furnace_note - 5*12
    return nss_note


#
# Debugging functions
#

def row_str(r, cols):
    semitones = [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
    if r.note == -1:
        notestr = "..."
    elif r.note == 180:
        notestr = "OFF"
    else:
        octave=r.note//12 - 5
        semitone=r.note%12
        notestr = "%s%s"%(semitones[semitone].ljust(2,"-"), octave)

    insstr = "%02X"%r.ins if r.ins != -1 else ".."
    volstr = "%02X"%r.vol if r.vol != -1 else ".."

    fxstr=""
    for f,v in r.fx[:cols]:
        sf = "%02X" % f if f!=-1 else ".."
        sv = "%02X" % v if v!=-1 else ".."
        fxstr += " %s%s" % (sf, sv)
    return "%s %s %s%s"%(notestr,insstr,volstr,fxstr)


dbg_order = 0
dbg_row = 0
dbg_channel = 0
dbg_fxs = 0

def dbg_pattern(p, m):
    cols = m.fxcolumns[p.channel]
    for r in p.rows:
        print(row_str(r, cols))


unknown_fx = {}
def add_unknown_fx(channel, fx):
    global unknown_fx
    s = unknown_fx.get(channel, set())
    s.add("%02x"%fx)
    unknown_fx[channel] = s

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
        ("jmp"     , ["lsb", "msb"]),
        ("nss_end" , ),
        ("tempo"   , ["val"]),
        ("wait_n"  , ["rows"]),
        ("call"    , ["lsb", "msb"]),
        ("nss_ret" , ),
        # 0x08
        ("nop"     , ),
        ("speed"   , ["ticks"]),
        ("groove",   ["ticks"]),
        ("wait_last", ),
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
        # 0x30
        ("fm_vibrato", ["speed_depth"]),
        ("fm_note_slide_u", ["speed_depth"]),
        ("fm_note_slide_d", ["speed_depth"]),
        ("b_vol"   , ["volume"]),
        ("a_vol"   , ["volume"]),
        ("fm_pan"  , ["pan_mask"]),
        ("fm_vol_slide_d", ["speed"]),
        ("s_vol_slide_d", ["speed"]),
        # 0x38
        ("fm_pitch_slide_d", ["speed"]),
        ("s_delay" , ["delay"]),
        ("fm_delay", ["delay"]),
        ("a_delay" , ["delay"]),
        ("b_ctx"   , ),
        ("fm_porta", ["speed"]),
        ("fm_pitch_slide_u", ["speed"]),
        ("s_pitch" , ["pitch"]),
        # 0x40
        ("b_pitch_slide_u", ["speed"]),
        ("s_pitch_slide_u", ["speed"]),
        ("b_porta", ["speed"]),
        ("s_pitch_slide_d", ["speed"]),
        ("s_porta", ["speed"]),
        ("fm_cut",   ["delay"]),
        ("s_cut",    ["delay"]),
        ("a_cut",    ["delay"]),
        # 0x48
        ("b_cut",    ["delay"]),
        ("b_delay",  ["delay"]),
        ("a_retrigger", ["delay"]),
        ("a_pan",    ["pan_mask"]),
        ("b_pan",    ["pan_mask"]),
        ("b_vibrato", ["speed_depth"]),
        ("call_tbl" , ["calls"]),
        ("fm_note_w" , ["note"]),
        # 0x50
        ("s_note_w"  , ["note"]),
        ("a_start_w" , ),
        ("fm_stop_w" , ),
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
# Additional internal opcodes
# generated by optimization passes
#

@dataclass
class call_entry:
    """references a pattern offset in the offset table of a NSS stream"""
    entry: int
    _opcode: int = field(default=0, repr=False)

@dataclass
class pat_offset:
    """offset of a pattern in bytes from the start of a NSS stream"""
    lsb: int
    msb: int
    _opcode: int = field(default=0, repr=False)


def convert_pan(fx, fxval):
    if fx == 0x08:  # pan
        pan_l = 0x80 if (fxval & 0xf0) else 0
        pan_r = 0x40 if (fxval & 0x0f) else 0
    elif fx == 0x80:  # old pan
        pan_l = 0x80 if fxval in [0x00, 0x80] else 0
        pan_r = 0x40 if fxval in [0x80, 0xff] else 0
    return pan_l|pan_r;


#
# Furnace module conversion functions
#
def convert_fm_row(row, channel):
    ctx_t = {0: fm_ctx_1, 1: fm_ctx_2, 2: fm_ctx_3, 3: fm_ctx_4}
    jmp_to_order = -1
    opcodes = []
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # volume (must be in the NSS stream before instrument)
        if row.vol != -1:
            opcodes.append(fm_vol(row.vol))
        # pre-instrument effects
        for fx, fxval in row.fx:
            if fx == 0xed:  # note delay
                opcodes.append(fm_delay(fxval))
        # instrument
        if row.ins != -1:
            opcodes.append(fm_instr(row.ins))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx in [0x08, 0x80, 0xed]: # pre-instrument FX
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x0f:  # Speed
                opcodes.append(speed(fxval))
            elif fx == 0x09:  # Groove
                opcodes.append(groove(fxval))
            elif fx == 0x04:  # vibrato
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(fm_vibrato(fxval))
            elif fx == 0x12:  # OP1 level
                opcodes.append(op1_lvl(fxval))
            elif fx == 0x13:  # OP2 level
                opcodes.append(op2_lvl(fxval))
            elif fx == 0x14:  # OP3 level
                opcodes.append(op3_lvl(fxval))
            elif fx == 0x15:  # OP4 level
                opcodes.append(op4_lvl(fxval))
            elif fx == 0xe5:  # pitch
                opcodes.append(fm_pitch(fxval))
            elif fx == 0xe1:  # slide up
                assert fxval != -1
                opcodes.append(fm_note_slide_u(fxval))
            elif fx == 0xe2:  # slide down
                assert fxval != -1
                opcodes.append(fm_note_slide_d(fxval))
            elif fx == 0x0a:  # volume slide down
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(fm_vol_slide_d(fxval))
            elif fx == 0x02:  # pitch slide down
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(fm_pitch_slide_d(fxval))
            elif fx == 0x01:  # pitch slide up
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(fm_pitch_slide_u(fxval))
            elif fx == 0x03:  # portamento
                opcodes.append(fm_porta(fxval))
            elif fx == 0xec:  # cut
                opcodes.append(fm_cut(fxval))
            elif fx in [0x08, 0x80]: # panning
                pan_mask = convert_pan(fx, fxval)
                opcodes.append(fm_pan(pan_mask))
            else:
                add_unknown_fx('FM', fx)

        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(fm_stop())
            else:
                opcodes.append(fm_note(to_nss_note(row.note)))
    return jmp_to_order, opcodes

def row_warn(row, msg):
    ch_str = ['F1','F2','F3','F4','S1','S2','S3','A1','A2','A3','A4','A5','A6','B']
    loc = "order %02X, row %3d (%s)"%(dbg_order, dbg_row,ch_str[dbg_channel])
    warn("%s: %s: %s"%(loc, msg, row_str(row, dbg_fxs)))

def s_vol_clamp(row):
    # TODO report proper location
    newvol = max(0, min(15, row.vol))
    if row.vol != newvol:
        rowstr = row_str(row, dbg_fxs)
        # warn("clamped volume to %02X: %s"%(newvol, rowstr))
        row_warn(row, "volume clamped to %02X"%newvol)
    return newvol

def convert_s_row(row, channel):
    ctx_t = {4: s_ctx_1, 5: s_ctx_2, 6: s_ctx_3}
    jmp_to_order = -1
    opcodes = []
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # pre note/vol effects
        for fx, fxval in row.fx:
            if fx == 0xed:  # note delay
                opcodes.append(s_delay(fxval))
        # instrument
        if row.ins != -1:
            opcodes.append(s_macro(row.ins))
        # volume
        if row.vol != -1:
            # bound checks w.r.t SSG limit
            row.vol = s_vol_clamp(row)
            opcodes.append(s_vol(row.vol))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx in [0xed]: # pre-instrument FX
                pass
            elif fx == 0x08:  # panning
                row_warn(row, "panning FX invalid for SSG")
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x0f:  # Speed
                opcodes.append(speed(fxval))
            elif fx == 0x09:  # Groove
                opcodes.append(groove(fxval))
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
            elif fx == 0xe5:  # set pitch (tune)
                opcodes.append(s_pitch(fxval))
            elif fx == 0x0a:  # volume slide down
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(s_vol_slide_d(fxval))
            elif fx == 0x01:  # pitch slide up
                # fxval == -1 means disable slide
                fxval = max(fxval, 0)
                opcodes.append(s_pitch_slide_u(fxval))
            elif fx == 0x02:  # pitch slide down
                # fxval == -1 means disable slide
                fxval = max(fxval, 0)
                opcodes.append(s_pitch_slide_d(fxval))
            elif fx == 0x03:  # pitch slide down
                opcodes.append(s_porta(fxval))
            elif fx == 0xec:  # cut
                opcodes.append(s_cut(fxval))
            else:
                add_unknown_fx('SSG', fx)

        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(s_stop())
            else:
                opcodes.append(s_note(to_nss_note(row.note)))
    return jmp_to_order, opcodes


def convert_a_row(row, channel):
    ctx_t = {7: a_ctx_1, 8: a_ctx_2, 9: a_ctx_3, 10: a_ctx_4, 11: a_ctx_5, 12: a_ctx_6}
    jmp_to_order = -1
    opcodes = []
    if not is_empty(row):
        # context
        opcodes.append(ctx_t[channel]())
        # pre-instrument effects
        for fx, fxval in row.fx:
            if fx == 0xed:  # note delay
                opcodes.append(a_delay(fxval))
        # instrument
        if row.ins != -1:
            opcodes.append(a_instr(row.ins))
        # volume
        if row.vol != -1:
            opcodes.append(a_vol(row.vol))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx in [0xed]: # pre-instrument FX
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x0c:  # retrigger
                opcodes.append(a_retrigger(fxval))
            elif fx == 0x0f:  # Speed
                opcodes.append(speed(fxval))
            elif fx == 0x09:  # Groove
                opcodes.append(groove(fxval))
            elif fx == 0xec:  # cut
                opcodes.append(a_cut(fxval))
            elif fx in [0x08, 0x80]: # panning
                pan_mask = convert_pan(fx, fxval)
                opcodes.append(a_pan(pan_mask))
            else:
                add_unknown_fx('ADPCM-A', fx)

        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(a_stop())
            else:
                opcodes.append(a_start())
    return jmp_to_order, opcodes


def convert_b_row(row, channel):
    jmp_to_order = -1
    opcodes = []
    if not is_empty(row):
        # pre note/vol/instrument effects
        for fx, fxval in row.fx:
            if fx == 0xed:  # note delay
                opcodes.append(b_delay(fxval))
        # instrument
        if row.ins != -1:
            opcodes.append(b_instr(row.ins))
        # volume
        if row.vol != -1:
            opcodes.append(b_vol(row.vol))
        # effects
        for fx, fxval in row.fx:
            if fx == -1:      # empty fx
                pass
            elif fx in [0xed]: # pre-instrument FX
                pass
            elif fx == 0x0b:  # Jump to order
                jmp_to_order = fxval
            elif fx == 0x0d:  # Jump to next order
                jmp_to_order = 256
            elif fx == 0xff:  # Stop song
                jmp_to_order = 257
            elif fx == 0x0f:  # Speed
                opcodes.append(speed(fxval))
            elif fx == 0x09:  # Groove
                opcodes.append(groove(fxval))
            elif fx == 0x01:  # pitch slide up
                # fxval == -1 means disable slide
                fxval = max(fxval, 0)
                opcodes.append(b_pitch_slide_u(fxval))
            elif fx == 0x03:  # portamento
                opcodes.append(b_porta(fxval))
            elif fx == 0xec:  # cut
                opcodes.append(b_cut(fxval))
            elif fx in [0x08, 0x80]: # panning
                pan_mask = convert_pan(fx, fxval)
                opcodes.append(b_pan(pan_mask))
            elif fx == 0x04:  # vibrato
                # fxval == -1 means disable vibrato
                fxval = max(fxval, 0)
                opcodes.append(b_vibrato(fxval))
            else:
                row_warn(row, "VIBRATO")
                add_unknown_fx('ADPCM-B', fx)

        # note
        if row.note != -1:
            if row.note == 180:
                opcodes.append(b_stop())
            else:
                opcodes.append(b_note(to_nss_note(row.note)))
    return jmp_to_order, opcodes


cached_nss = {}
def raw_nss(m, p, bs, channels, compact):
    global dbg_order, dbg_row

    # a cache of already parsed rows data
    def row_to_nss(func, pat, pos):
        global cached_nss, dbg_channel, dbg_fxs
        idx=(pat.channel, pat.index, pos)
        if idx not in cached_nss:
            dbg_channel = pat.channel
            dbg_fxs = m.fxcolumns[pat.channel]
            cached_nss[idx] = func(pat.rows[pos], pat.channel)
        return cached_nss[idx]

    # unoptimized nss opcodes generated from the Furnace song
    nss = []

    f_channels = list(range(0,3+1))
    s_channels = list(range(4,6+1))
    a_channels = list(range(7,12+1))
    b_channel = list([13])
    selected_f = [x for x in f_channels if x in channels]
    selected_s = [x for x in s_channels if x in channels]
    selected_a = [x for x in a_channels if x in channels]
    selected_b = [x for x in b_channel if x in channels]

    # initialize stream speed from module
    tick = m.speeds[0]

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
    seen_patterns=[]
    order=0

    blocks = []

    while order < len(m.orders) and order not in seen_orders:
        # recall we've processed this order and set its location in the stream
        seen_orders.append(order)

        #  -1: no jump required after row processed
        #   n: jump to order n for the next row to play
        # 256: jump to the next order for the next row to play
        # 257: jump outside the stream (i.e. stop)
        jmp_to_order = -1

        # get pattern indices for current order
        pattern_indices = m.orders[order]
        order_patterns = [p[(m.orders[order][f],f)] for f in range(14)]

        # reference start of order
        jmp_label = nss_label("jmp_%x"%order)
        nss.append(jmp_label)

        # all channels should have the same number of rows
        pattern_length = len(order_patterns[0].rows)
        assert len(set([len(p.rows) for p in order_patterns])) == 1
        assert pattern_length == m.pattern_len

        pattern_opcodes = []
        for index in range(pattern_length):
            # nss opcodes to add at the end of each processed Furnace row
            opcodes = []
            dbg_order, dbg_row = order, index

            # FM channels
            for channel in f_channels:
                j, f_opcodes = row_to_nss(convert_fm_row, order_patterns[channel], index)
                if channel in selected_f:
                    opcodes.extend(f_opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # SSG channels
            for channel in s_channels:
                # dbg_channel = channel
                # row = order_patterns[channel].rows[index]
                # j, s_opcodes = convert_s_row(row, channel)
                j, s_opcodes = row_to_nss(convert_s_row, order_patterns[channel], index)
                if channel in selected_s:
                    opcodes.extend(s_opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # ADPCM-A channels
            for channel in a_channels:
                # dbg_channel = channel
                # row = order_patterns[channel].rows[index]
                # j, a_opcodes = convert_a_row(row, channel)
                j, a_opcodes = row_to_nss(convert_a_row, order_patterns[channel], index)
                if channel in selected_a:
                    opcodes.extend(a_opcodes)
                jmp_to_order = max(jmp_to_order, j)
            # ADPCM-B channel
            for channel in b_channel:
                # dbg_channel = channel
                # row = order_patterns[channel].rows[index]
                # j, b_opcodes = convert_b_row(row, channel)
                j, b_opcodes = row_to_nss(convert_b_row, order_patterns[channel], index)
                if channel in selected_b:
                    opcodes.extend(b_opcodes)
                jmp_to_order = max(jmp_to_order, j)

            # all channels are processed for this pos.
            # add all generated opcodes plus a time sync
            pattern_opcodes.extend(opcodes + [wait_n(1)])

            # stop processing further rows if a JMP fx was used
            if jmp_to_order != -1:
                break

        if 0 <= jmp_to_order and jmp_to_order != 256:
            order = jmp_to_order
        else:
            order += 1

        if compact:
            # if this pattern was already processed, do not remember it twice
            # NOTE: sometimes a patterns appears in a order where full playback
            # is squeezed by a jump action from another pattern. In that case
            # we have to consider that as a new pattern.
            # To account for that, a pattern is identified by its index _and_
            # its length.
            pattern_index = pattern_indices[channels[0]]
            pattern_waits = [x for x in pattern_opcodes if isinstance(x, wait_n)]
            pattern_length = sum([x.rows for x in pattern_waits])
            channel = channels[0]
            pattern_id = "%s_%02x_%02x"%(channel_name(channel),pattern_index,pattern_length)
            if not pattern_id in seen_patterns:
                # compact representation: labeled pattern that can be jump to
                pattern_label = nss_label(pattern_id)
                basic_block = [pattern_label] + pattern_opcodes + [nss_ret()]
                blocks.extend(basic_block)
                seen_patterns.append(pattern_id)
            call_op = call(-1, -1)
            call_op.pat = pattern_id
            nss.append(call_op)
        else:
            nss.extend(pattern_opcodes)

    if order in seen_orders:
        # the last order was already processed, the stream will loop
        nloop = jmp(-1, -1)
        nloop.pat="jmp_%x"%order
        nss.append(nloop)
    else:
        # orders were processed in sequence, the stream will end
        nss.append(nss_end())
    # add the pattern blocks that get called at the end of the stream,
    # past the end opcode.
    nss.extend(blocks)
    return nss


#
# NSS optimization passes
#

def merge_adjacent_waits(nss):
    compact = []
    cur_wait = 0
    for op in nss:
        if type(op) == wait_n:
            cur_wait += op.rows
            # the wait opcode cannot encode more than 255 ticks
            if cur_wait>255:
                new_wait = wait_n(255)
                compact.append(new_wait)
                cur_wait -= 255
        else:
            if cur_wait>0:
                new_wait = wait_n(cur_wait)
                compact.append(new_wait)
                cur_wait=0
            compact.append(op)
    return compact


def compact_wait_n_last(nss):
    last_rows = -1

    def compact_wait_n_last_pass(op, out):
        nonlocal last_rows
        if type(op) == nss_label:
            last_rows = -1
            out.append(op)
        elif type(op) == wait_n:
            if op.rows == last_rows:
                out.append(wait_last())
            else:
                last_rows = op.rows
                out.append(op)
        else:
            out.append(op)

    out = run_control_flow_pass(compact_wait_n_last_pass, nss)
    return out


def fuse_note_wait_last(nss):
    fuse_map = {fm_note: fm_note_w,
                s_note: s_note_w,
                a_start: a_start_w,
                fm_stop: fm_stop_w}
    note_op = False
    start_stop_op = False

    def fuse_note_wait_last_pass(op, out):
        nonlocal note_op
        nonlocal start_stop_op
        if type(op) == wait_last:
            if note_op:
                fused_op = fuse_map[type(note_op)](note_op.note)
                out.append(fused_op)
                note_op = False
            elif start_stop_op:
                fused_op = fuse_map[type(start_stop_op)]()
                out.append(fused_op)
                start_stop_op = False
            else:
                out.append(op)
        elif type(op) in [fm_note, s_note]:
            assert start_stop_op == False
            note_op = op
        elif type(op) in [a_start]:
            assert note_op == False
            start_stop_op = op
        else:
            if note_op:
                out.append(note_op)
                note_op = False
            if start_stop_op:
                out.append(start_stop_op)
                start_stop_op = False
            out.append(op)

    out = run_control_flow_pass(fuse_note_wait_last_pass, nss)
    return out


def compact_instr(nss):
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

    def compact_instr_pass(op, out):
        nonlocal fm_ctx
        nonlocal s_ctx
        nonlocal a_ctx
        nonlocal b_i
        nonlocal fm_is
        nonlocal s_is
        nonlocal a_is
        nonlocal b_i
        if type(op) == nss_label:
            fm_is = [-1, -1, -1, -1]
            s_is = [-1, -1, -1]
            a_is = [-1, -1, -1, -1, -1, -1]
            b_i = -1
            out.append(op)
        elif type(op) == fm_instr:
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

    out = run_control_flow_pass(compact_instr_pass, nss)
    return out


def compact_calls(nss):
    compact = []

    offset = {}
    entries = []

    tmpid = 0
    def add_call(op):
        nonlocal tmpid
        if op.pat not in offset:
            tmpid -= 1
            idx = tmpid
            offset[op.pat] = idx
        else:
            idx = offset[op.pat]
        entries.append(op)

    for op in nss:
        if type(op) == call:
            add_call(op)
        else:
            if entries:
                compact.append(call_tbl(len(entries)))
                for e in entries:
                    entry = call_entry(offset[e.pat])
                    entry.pat = e.pat
                    entry.desc = "for %s"%e.pat
                    compact.append(entry)
                entries = []
            compact.append(op)
    offsets = []
    for v, k in sorted([(v,k) for k,v in offset.items()]):
        o = pat_offset(-1,-1)
        o.pat = k
        o.desc = "for %s"%k
        offsets.append(o)
    compact = offsets + compact #[nss_label('_start')] + compact
    return compact



def tune_adpcm_b_notes(nss, ins):
    # for ADPCM-B, the playback frequency depends on the instrument in use:
    #   . the C-4 note is played back at the current instrument's sample frequency
    #   . every other semitone has a frequency that is based on the instrument's C-4 frequency
    #   . each frequency must be converted to Delta-N for the YM2610
    # nullsound does not work with Delta-N nor frequencies directly, it has to reason
    # with fixed-point semitones to implements FX
    #   . internally, nullsound has a table of possible Delta-N (one Delta-N per semitone)
    #   . a given frequency lies between two consecutive entries in the Delta-N table (fixed point)
    #   . for each ADPCM-B instrument parsed, furtool maps the C-4 note to an entry in the Delta-N
    #     table, plus a fractional displacement to the closest Delta-N to get the desired frequency

    semitones = [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]

    # all notes in the ADPCM-B channel are relative to C-4
    c4 = (4*12)+0
    # current instrument for ADPCM-B
    current_inst = -1
    # instrument's Delta-N index for C-4 frequency
    inst_delta_n_idx = 0

    def note_str(note):
        octave, semitone = note // 12, note % 12
        return semitones[semitone].ljust(2, '-')+str(octave)

    def tune_adpcm_b_pass(op, out):
        nonlocal c4
        nonlocal current_inst
        nonlocal inst_delta_n_idx

        if type(op) == nss_label:
            current_inst = -1
            out.append(op)
        elif type(op) == b_instr:
            if current_inst != op.inst:
                current_inst = op.inst
                inst_delta_n_idx = ins[current_inst].c4_delta_n_idx
                # temporary workaround to support arpeggio tweak from macro
                inst_delta_n_idx += ins[current_inst].tuned
                out.append(op)
        elif type(op) == b_note:
            # get the semitone offset from c4
            semitone_offset = op.note - c4
            # the "tuned" note is the note to use in nullsound to configure the
            # right frequency in the YM2610 (i.e. the semitone offset from the
            # sample's base frequency)
            idx_offset = inst_delta_n_idx + semitone_offset
            out.append(b_note(idx_offset))
        else:
            out.append(op)

    out = run_control_flow_pass(tune_adpcm_b_pass, nss)
    return out


def remove_ctx(nss):
    ctxs = [fm_ctx_1, fm_ctx_2, fm_ctx_3, fm_ctx_4,
            s_ctx_1, s_ctx_2, s_ctx_3,
            a_ctx_1, a_ctx_2, a_ctx_3, a_ctx_4, a_ctx_5, a_ctx_6]
    out = [x for x in nss if type(x) not in ctxs]
    return out


def compact_ctx(nss):
    fm_ctx_map = {fm_ctx_1: 0, fm_ctx_2: 1, fm_ctx_3: 2, fm_ctx_4: 3}
    s_ctx_map = {s_ctx_1: 0, s_ctx_2: 1, s_ctx_3: 2}
    a_ctx_map = {a_ctx_1: 0, a_ctx_2: 1, a_ctx_3: 2, a_ctx_4: 3, a_ctx_5: 4, a_ctx_6: 5}
    fm_ctx = 0
    s_ctx = 0
    a_ctx = 0

    def compact_ctx_pass(op, out):
        nonlocal fm_ctx
        nonlocal s_ctx
        nonlocal a_ctx
        if type(op) in [wait_n, wait_last]:
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
            if fm_ctx == val: return
            else: fm_ctx = val
        elif type(op) in s_ctx_map.keys():
            val = s_ctx_map[type(op)]
            if s_ctx == val: return
            else: s_ctx = val
        elif type(op) in a_ctx_map.keys():
            val = a_ctx_map[type(op)]
            if a_ctx == val: return
            else: a_ctx = val
        out.append(op)

    out = run_control_flow_pass(compact_ctx_pass, nss)
    return out


def stream_from_label(stream, label):
    label = next((i for i, v in enumerate(stream) if isinstance(v,nss_label) and v.pat==label))
    ret = next((i for i, v in enumerate(stream[label:]) if isinstance(v,nss_ret)))
    return stream[label:label+ret+1]


def run_control_flow_pass(pass_function, nss):
    # a stream is composed of the main sequence of opcodes and
    # optionally a series of blocks at the end, that are called by the
    # main sequence.
    out_main = []
    out_blocks = []
    # make sure we dump the block only once in the output
    seen_blocks = {}
    # current stream to push output opcodes to
    out = out_main
    # a stream can use call/ret opcodes, with a stack that is one call deep.
    prev_stream = []
    stream = list(nss)

    while stream:
        op = stream.pop(0)
        if type(op) in [call, call_entry]:
            out.append(op)
            if op.pat not in seen_blocks:
                seen_blocks[op.pat] = True
                out = out_blocks
            else:
                # evaluate this block to keep context up to date
                # but do not keep the generated opcodes
                out = []
            prev_stream = stream
            stream = stream_from_label(stream, op.pat)
        elif type(op) == nss_ret:
            out.append(op)
            out = out_main
            stream = prev_stream
        elif type(op) in [jmp, nss_end]:
            out.append(op)
            break
        else:
            pass_function(op, out)

    return out_main + out_blocks


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
    s_ctx_map = {s_ctx_1: 0, s_ctx_2: 1, s_ctx_3: 2}
    s_ctx = 0
    s_is = [-1, -1, -1]
    s_autoenv = [False, False, False]
    s_period = [-1, -1, -1]

    def autoenv_pass(op, out):
        nonlocal s_ctx
        if type(op) in [wait_n, wait_last]:
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
                o = (op.note // 12) + 1
                n = op.note % 12
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

    out = run_control_flow_pass(autoenv_pass, nss)
    return out


def remove_unreferenced_labels(nss):
    labels = [x for x in nss if isinstance(x, nss_label)]
    callers = [x for x in nss if type(x) in [jmp, call]]
    refs = set([x.pat for x in callers])

    out = []
    for op in nss:
        if isinstance(op, nss_label) and op.pat == '_start':
            # special case for start of stream
            out.append(op)
        elif isinstance(op, nss_label) and op.pat not in refs:
            continue
        else:
            out.append(op)
    return out


def resolve_jmp_and_call_opcodes(nss):
    labels = {}
    # pass: position of each label in the stream (offset in bytes from start)
    pos = 0
    start_pos = 0
    for op in nss:
        if isinstance(op, nss_label):
            labels[op.pat] = pos
            if op.pat == '_start':
                start_pos = pos
        else:
            # 1 byte per args, do not count the 1 metadata arg
            pos += len(astuple(op))-1
            # 1 byte for the opcode ID if required
            if op._opcode > 0:
                pos+=1

    # pass: resolve jmp and call opcodes
    for op in nss:
        if type(op) in [jmp, call, pat_offset]:
            # the real offset is w.r.t the start of the stream,
            # not counting the call entries
            label_offset = labels[op.pat] - start_pos
            op.lsb = label_offset & 0xff
            op.msb = (label_offset>>8) & 0xff

    return nss


def remove_empty_streams(channels, streams):
    def control_flow(op):
        return type(op) in [jmp, call, nss_ret, nss_label, nss_end, wait_n, wait_last]
    def stream_effective_length(s):
        return len([op for op in s if not control_flow(op)])
    streams_lengths = [(c, s, stream_effective_length(s)) for c, s in zip(channels, streams)]
    non_empty = [(c, s) for c, s, l in streams_lengths if l > 0]
    return [c for c, s in non_empty], [s for c, s in non_empty]


def stream_size(stream):
    def op_size(op):
        if isinstance(op, nss_label):
            return 0
        else:
            # size: data size (without metadata fields)
            size = len(astuple(op)) - 1
            # if needed, count an additional byte for the opcode ID
            # if op._count_op or op._opcode > 0:
            if op._opcode > 0:
                size+=1
            return size

    sizes = [op_size(op) for op in stream]
    return sum(sizes)


def asm_header(nss, m, name, bank, size, fd):
    print(";;; NSS music data", file=fd)
    print(";;; generated by nsstool.py (ngdevkit)", file=fd)
    print(";;; ---", file=fd)
    print(";;; Song title: %s" % m.name, file=fd)
    print(";;; Song author: %s" % m.author, file=fd)
    print(";;; NSS size: %d" % size, file=fd)
    print(";;;", file=fd)
    print("", file=fd)
    if bank != None:
        print("        .area   BANK%d"%bank, file=fd)
    else:
        print("        .area   CODE", file=fd)
    print("", file=fd)


def channel_name(channel):
    stream_type = ["f1", "f2", "f3", "f4", "s1", "s2", "s3",
                   "a1", "a2", "a3", "a4", "a5", "a6", "b"]
    return stream_type[channel]


def stream_name(prefix, channel):
    return prefix+"_%s"%channel_name(channel)


def nss_compact_header(mod, channels, streams, name, fd):
    bitfield, comment = channels_bitfield(channels)
    if name:
        print("%s::" % name, file=fd)
    print(("        .db     0x%02x"%len(streams)).ljust(40)+" ; number of streams", file=fd)
    print(("        .dw     0x%04x"%bitfield).ljust(40)+" ; channels: %s"%comment, file=fd)
    speeds=", ".join(["0x%02x"%x for x in mod.speeds])
    print(("        .db     0x%02x, %s"%(len(mod.speeds), speeds)).ljust(40)+" ; speeds", file=fd)
    for i, c in enumerate(channels):
        comment = "stream %i: NSS data"%i
        print(("        .dw     %s"%(stream_name(name,c))).ljust(40)+" ; "+comment, file=fd)
    print("", file=fd)


def nss_inline_header(channels, name, fd):
    bitfield, comment = channels_bitfield(channels)
    if name:
        print("%s::" % name, file=fd)
    print("        .db     0xff".ljust(40)+" ; inline NSS stream marker", file=fd)
    print(("        .dw     0x%04x"%bitfield).ljust(40)+" ; channels: %s"%comment, file=fd)


def nss_footer(name, fd):
    print("%s_end::" % name, file=fd)


def nss_to_asm(nss, m, name, fd):
    def asm_slice(nss):
        for op in nss:
            if isinstance(op, nss_label):
                if op.pat == "_start":
                    print("        ;; start of NSS stream", file=fd)
                elif "jmp" not in op.pat:
                    print("        ;; pattern %s"%(op.pat,), file=fd)
                continue
            op_data = []
            # if op._count_op or op._opcode > 0:
            if op._opcode > 0:
                op_data.append(op._opcode)
            op_data.extend(astuple(op)[:-1])
            hexdata = ", ".join(["0x%02x"%(x&0xff,) for x in op_data])
            comment = " ; %s"%type(op).__name__.upper()
            if "desc" in dir(op):
                comment+=" "+op.desc
            # if isinstance(op, call):
            #     comment+=" "+op.pat
            print("        .db     "+hexdata.ljust(24)+comment, file=fd)

    start = next(i for i,v in enumerate(nss) if isinstance(v, nss_label) and v.pat == '_start')
    call_offsets = nss[:start]
    stream_ops = nss[start:]
    if call_offsets:
        print("\n        ;; call entries for %s"%(name,), file=fd)
        asm_slice(call_offsets)
    if name:
        print("%s::" % name, file=fd)
    asm_slice(stream_ops)


def generate_nss_stream(m, p, bs, ins, channels, stream_idx):
    compact = stream_idx >= 0

    dbg("Convert Furnace patterns to unoptimized NSS opcodes")
    nss = raw_nss(m, p, bs, channels, compact)

    if stream_idx <= 0:
        tb = round(256 - (4000000 / (1152 * m.frequency)))
        nss.insert(0, tempo(tb))

    nss.insert(0, nss_label("_start"))

    dbg("Transformation passes:")
    dbg(" - remove unreference NSS labels")
    nss = remove_unreferenced_labels(nss)

    dbg(" - merge adjacent WAIT opcodes")
    nss = merge_adjacent_waits(nss)

    dbg(" - remove successive INSTR opcodes if they keep intrument unchanged")
    nss = compact_instr(nss)

    dbg(" - compact WAIT_N -> WAIT_LAST opcodes")
    nss = compact_wait_n_last(nss)

    dbg(" - fuse sequences of NOTE / WAIT_LAST opcodes")
    nss = fuse_note_wait_last(nss)

    dbg(" - compact CALL opcodes into CALL_TABLE opcodes")
    nss = compact_calls(nss)

    dbg(" - tune ADPCM-B notes based on instrument's sample speed")
    nss = tune_adpcm_b_notes(nss, ins)

    if compact:
        dbg(" - remove CTX opcodes for compact stream")
        nss = remove_ctx(nss)
    else:
        dbg(" - remove CTX opcodes if they keep the current context unchanged")
        nss = compact_ctx(nss)

    dbg(" - look for SSG autoenv macros and insert opcodes to simulate them")
    nss = simulate_ssg_autoenv(nss, ins)

    dbg(" - resolve jmp and call opcodes")
    nss = resolve_jmp_and_call_opcodes(nss)

    return nss


def channels_bitfield(channels):
    channels_names = ["F1", "F2", "F3", "F4", "S1", "S2", "S3", "__",
                      "A1", "A2", "A3", "A4", "A5", "A6", "B", "__"]
    # reorganise ADPCM bits in a dedicated byte
    updpos = [x+1 if x>6 else x for x in channels]
    bitword = sum([1<<x for x in updpos])

    # create a description of used channels among the 14 available
    used_channels = [channels_names[x] if bitword&(1<<x) else "" for x in range(15)]
    comment = ",".join(list(filter(lambda x: x,used_channels)))

    return bitword, comment


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description="Convert Furnace module patterns to NSS stream")

    parser.add_argument("FILE", help="Furnace module")
    parser.add_argument("-o", "--output", help="Output file name")

    parser.add_argument("-b", "--bank", type=int,
                       help="generate data for a bank-switched Z80 memory area")

    parser.add_argument("-n", "--name",
                        help="Name of the ASM label for the NSS data. Empty name skips label.")

    parser.add_argument("-c", "--channels", help="Process specific channels. One hex digit per channel", default='0123456789abcd')
    parser.add_argument("-z", "--compact", help="Generate compact NSS stream", action="store_true")

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

    bank = arguments.bank

    # validate channel filtering option
    if not all(['0' <= c <= 'd' for c in arguments.channels.lower()]):
        error("invalid channel filter")

    register_nss_ops()

    dbg("Loading Furnace module %s"%arguments.FILE)
    bs = load_module(arguments.FILE)
    m = read_module(bs)
    smp = read_samples(module_id_from_path(arguments.FILE), m.samples, bs)
    ins = read_instruments(m.instruments, smp, bs)
    p = read_all_patterns(m, bs)
    channels = [int(c, 16) for c in sorted(list(arguments.channels.lower()))]

    if arguments.compact:
        streams = [generate_nss_stream(m, p, bs, ins, [c], i) for i, c in enumerate(channels)]
        channels, streams = remove_empty_streams(channels, streams)
        # NSS compact header (number of streams, channels bitfield, stream pointers)
        size = (1 +                  # number of streams
                2 +                  # channels bitfield
                1 + len(m.speeds) +  # speeds
                (2 * len(streams)))  # stream pointers
        # all streams sizes
        size += sum([stream_size(s) for s in streams])
        asm_header(streams, m, name, bank, size, outfd)
        nss_compact_header(m, channels, streams, name, outfd)
        for i, ch, stream in zip(range(len(channels)), channels, streams):
            nss_to_asm(stream, m, stream_name(name, ch), outfd)
    else:
        stream = generate_nss_stream(m, p, bs, ins, channels, -1)
        # NSS inline marker + channels bitfield, stream size
        size = 1 + 2 + stream_size(stream)
        asm_header(stream, m, name, bank, size, outfd)
        nss_inline_header(channels, name, outfd)
        nss_to_asm(stream, m, False, outfd)
    nss_footer(name, outfd)

    # warn about any unknown FX during the conversion to NSS
    for ch in unknown_fx.keys():
        warn("unknown FX for %s: %s" % (ch, ", ".join(sorted(unknown_fx[ch]))))



if __name__ == "__main__":
    main()
