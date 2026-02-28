#!/usr/bin/env python3
# Copyright (c) 2026 Damien Ciabrini
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

"""Generate FM F-num and SSG tune precomputed tables (MVS/AES)"""

import argparse
import sys
from os.path import basename
from enum import Enum
from itertools import batched, chain


class ChannelType(Enum):
    FM = "fm"
    SSG = "ssg"

    def __str__(self):
        return self.value


class Clock(Enum):
    MVS = "mvs"
    AES = "aes"

    def __str__(self):
        return self.value


class NSS:
    """Common utility functions for precomputed table generation"""

    # all frequencies are derived from A-4 following equal temperament, with a standard 440Hz tuning
    A4TUNING = 440

    # - there are 7*12 = 84 integer semitones in nullsound, representing notes C-1 to B-7
    # - the frequency f of each semitone s follows the equal temperament system:
    #     f(s) = 440 * 2^(s/12)
    #   where s=0 is the A-4 notes.
    # - C-1 to B-7 semitones are offsets from A-4 (e.g. C-1 = -45, ..., B-7 = 39)
    # - a decimal semitone is a pitched semitone, whose frequency is between the frequency
    #   of its two nearest integer semitones
    a4semitones = [i - 45 for i in range(7 * 12)]

    semitones = ["C-n", "C#n", "D-n", "D#n", "E-n", "F-n", "F#n", "G-n", "G#n", "A-n", "A#n", "B-n"]

    def get_delta_table(freq_fun):
        """return the delta table for 128 steps between two adjacent integer semitones, i.e.
        if f(x) is the configured YM2610 value for a decimal semitone x between two adjacent
        semitones s and s+1 (where f(s) <= f(x) < f(s+1)), then the delta factor of x is the
        normalized position ([0..1[) between the YM2610 values of the two adjacent semitones.
        """
        # there are 128 pitched semitones between two integer semitones.
        # Each 128th substep yields a specific YM2610 value and this is not exactly a 128th
        # of the distance between the closest semitones' respective YM2610 values. This is
        # because the YM2610 value for a semitone s is a function of the semitone's frequency
        # f(s)=440*2^((s-45)/12), which is not a linear transformation.
        #
        # We can however precompute the YM2610 value of a pitched semitone and express it as
        # a delta factor [0..1[ between the YM2610 values of its two closest semitones.
        # [0: lower semitone .. 1:higher semitone[
        # The delta factors for all 128 substeps are the same whatever the subsequent
        # semitones considered, so we only need to precompute 128 delta factors to know
        # the exact frequency of every possible substep for all the 7*12 semitones in NSS.

        # exact (e.g. floating point) deltas [0.0..1.0[ for all possible 128 substeps
        deltas = [(freq_fun(0 + (i / 128)) - freq_fun(0)) / (freq_fun(0 + 1) - freq_fun(0)) for i in range(128)]

        # approximated deltas (0:16 fixed point) for all possible 128 substeps
        deltas_fp = [int(d * 65536) for d in deltas]
        return deltas_fp

    def notename(a4idx):
        s = a4idx + 45 + 12
        octave = s // 12
        note = NSS.semitones[s % 12].replace("n", str(octave))
        return note

    def pp_tune_fp(tune_fp):
        hx = "%06X" % tune_fp
        return hx[0:3] + "." + hx[3:]

    def chk(val, ref):
        if val == ref:
            return "%s" % val
        else:
            return "\x1b[38;5;9m%s\x1b[39m" % val

    def chk_fp(val, ref):
        valint, valfract = val >> 12, val & 0xFFF
        if valint == ref:
            return "%03x%03x" % (valint, valfract)
        else:
            return "\x1b[38;5;9m%03x\x1b[39m%03x" % (valint, valfract)

    def shifts(x, bits):
        res = []
        for i in range(bits):
            x = x >> 1
            res.append(x)
        return res

    def lshifts(x, bits):
        res = []
        for i in range(bits):
            res.append(x)
            x = x << 1
        return list(reversed(res))

    def bins(x, bits):
        return [((2**i) & x) >> i for i in range(bits - 1, -1, -1)]

    def z80_mul(realfplen, deltafp, precision):
        pow_fracts = NSS.shifts(realfplen, precision)
        scale = NSS.bins(deltafp, precision)
        return sum([a * b for a, b in zip(pow_fracts, scale)])

    # Precompute all pitched values for a channel and compare against Furnace's output
    def compute_pitches(pitchs, fun):
        allerrs = []
        total_notes = 7 * 12
        print("\x1bc", end="")
        for loop, pitch in enumerate(pitchs):
            print("\033[1;1f", end="")
            allerrs.extend(fun(pitch, allerrs))
            print("\ntotal: ", loop + 1, "shifts,", (loop + 1) * total_notes, "combinations -", len(allerrs), "errors")
            # input('')
        print("\n-----\n")
        if allerrs:
            print("Found discrepancies with Furnace:")
            for e in allerrs:
                print(e)

    # print generic data table in ASM format
    def dump(data, name, datasize, labels="", chunks=8, cols=8):
        dtype = ".dw" if datasize == 2 else ".db"
        datafmt = "0x%04x" if datasize == 2 else "0x%02x"
        labelfmt = "%6s" if datasize == 2 else "%4s"
        if name:
            print("\n        .macro ." + name + "_data")
        if labels:
            print("        ;;      " + ", ".join([labelfmt % l for l in labels]))
        for row in batched(data, chunks):
            vals = [datafmt % i for i in row]
            vals.extend(["0"] * (cols - len(vals)))
            print("        " + dtype + "     " + ", ".join(vals))
        if name:
            print("        .endm")

    def dumpv(rawdata, name, labels="", chunks=3):
        def hex24(f):
            return [(f >> (s * 8)) & 0xFF for s in range(chunks)]

        data = chain(*[hex24(f) for f in rawdata])
        if name:
            print("\n        .macro ." + name + "_data")
        ilabels = iter(labels + [l + "+1" for l in labels])
        for row in batched(data, chunks):
            vals = ["0x%02x" % i for i in row]
            lab = "    ; " + next(ilabels) if labels else ""
            print("        .db     " + ", ".join(vals) + lab)
        if name:
            print("        .endm")


class SSG(NSS):
    """Generator for precomputed SSG note tables"""

    def __init__(self, clock):
        # YM2610 clock frequency for computations
        if clock == Clock.MVS:
            self._8M = 24000000 / 3
        else:
            self._8M = 24167829 / 3

        # Original Furnace data to validate generated precomputed data
        if clock == Clock.MVS:
            from fur_ssg_mvs import furdata
        else:
            from fur_ssg_aes import furdata
        self.furdata = furdata

        # SSG tune approximation (12:12 fixed point) for all semitones C-1..B-7 (84 semitones)
        self.all_tunes_fp = [self.tune_fp(NSS.a4semitones[i]) for i in range(len(NSS.a4semitones))]
        # NOTE: an additional item just to compute the last value of the diff table below
        self.all_tunes_fp.append(self.tune_fp(NSS.a4semitones[len(NSS.a4semitones) - 1] + 1))

        # Tweaks: with our fixed-point approximation, we are slightly off from
        # what Furnace generates for a handful of semitones+pitch combinations.
        # By fine-tuning the fixed-point SSG tune approximation by a minuscule amount,
        # we can erase the small differences and stick exactly to Furnace values.
        if clock == Clock.MVS:
            # MVS tweaks
            self.all_tunes_fp[16] -= 0x3
            self.all_tunes_fp[52] -= 0x1
            self.all_tunes_fp[78] -= 0x3
        else:
            # AES tweaks
            self.all_tunes_fp[23] -= 0x3
            self.all_tunes_fp[35] -= 0x3

        # Distance between SSG tune for all semitones
        self.all_ssg_dists = [self.all_tunes_fp[i] - self.all_tunes_fp[i + 1] for i in range(len(NSS.a4semitones))]
        # Additional item no longer needed after diff computation
        self.all_tunes_fp.pop()

        # Delta table for SSG tunes
        self.ssg_deltas_fp = NSS.get_delta_table(lambda x: self.tune_f(x))

    def freq(self, a4semitone_f):
        """Decimal frequency (floating point) for a decimal semitone (floating point)"""
        freq_f = NSS.A4TUNING * 2 ** ((a4semitone_f) / 12)
        return freq_f

    def tune_f(self, a4semitone_f):
        """SSG tune (floating point) associated with a decimal semitone (floating point)"""
        freq_f = NSS.A4TUNING * (2 ** (a4semitone_f / 12))
        # From YM2610 doc: SSG tune = masterclock / (64 * freq)
        tune_no_round = self._8M / (64 * freq_f)
        return tune_no_round

    def tune_fp(self, a4semitone_f):
        """Approximated SSG tune (12:12 fixed point) associated with a decimal semitone (floating point)"""
        tune = self.tune_f(a4semitone_f)
        tune_fp = int(tune * (2**12))
        return tune_fp

    def round_tune_fp(self, tune_fp):
        """F-num (12:12 fixed point) to get an integer F-num"""
        round_i = tune_fp + (1 << 11)  # +0.5
        return round_i

    def tune_i(self, a4semitone_f):
        """F-num (integer) associated with a decimal semitone (floating point)"""
        return round(self.tune_f(a4semitone_f))

    def validate_all_pitches(self, pitches):
        NSS.compute_pitches(pitches, lambda p, e: self.validate_all_notes_for_pitch(p))

    def validate_all_notes_for_pitch(self, pitch):
        print(
            "pitch  note           bin       int fur     nss_fp       diff    factor      delta    pitch_fp  rounded   fur\n"
        )
        errs = []
        # iterate over all notes considered in NSS (7 octaves)
        for s in range(0, 7 * 12):
            strg, diff = self.validate_note(s, pitch)
            print(strg)
            if diff:
                errs.append(strg)
        return errs

    def validate_note(self, s, pitch):
        substep = pitch / 128
        strg = ""

        # semitone offset from A-4
        a4semitone = NSS.a4semitones[s]
        strg += "\x1b[2K\r[%03d] %02d %s" % (pitch, s, NSS.notename(a4semitone))

        # the value generated by Furnace, i.e. the value we have to match
        fur = self.furdata[pitch][s]

        # real pitched SSG tune, with right rounding (as computed by Furnace)
        real_pitched_tune_i = self.tune_i(a4semitone + substep)
        real_str = NSS.chk("%03x" % real_pitched_tune_i, "%03x" % fur)
        strg += "  |  [%s] %03x %3s" % (bin(real_pitched_tune_i)[2:].zfill(12), fur, real_str)

        # build the approximated position of this pitched semitone
        # (with the help of a fixed-point delta factor)

        # . start with the non-pitched fixed-point SSG tune for this semitone
        approx_tune_fp = self.all_tunes_fp[s]
        strg += "  |  %06x" % (approx_tune_fp)

        # . then build the displacement from the delta factor
        bits = 16
        precision = 2**bits
        distance_to_prev_approx_tune_fp = self.all_ssg_dists[s]
        pitch_delta_fp = self.ssg_deltas_fp[pitch]
        strg += "  | + %06x x 0.%04x" % (distance_to_prev_approx_tune_fp, pitch_delta_fp)
        distance_to_approx_pitched_tune_fp = (distance_to_prev_approx_tune_fp * pitch_delta_fp) // precision
        approx_pitched_tune_fp = approx_tune_fp - distance_to_approx_pitched_tune_fp
        strg += "  | + %06x = %06x" % (distance_to_approx_pitched_tune_fp, approx_pitched_tune_fp)

        # . at last, apply the Furnace rounding to get the SSG tune
        approx_rounded_pitched_tune_fp = self.round_tune_fp(approx_pitched_tune_fp)
        strg += "  | %s" % NSS.chk_fp(approx_rounded_pitched_tune_fp, real_pitched_tune_i)

        # for comparison purpose, show the real SSG tune next to the NSS computed value
        strg += "  | %03x" % (real_pitched_tune_i)

        nss_tune_i = int(approx_rounded_pitched_tune_fp) >> 12
        return strg, nss_tune_i != fur

    def dump_tables(self):
        hw = "MVS" if self._8M == 8000000 else "AES"
        print(";;; SSG pitched note tables (%s) for nullsound, the ngdevkit sound driver" % hw)
        print(";;; Generated with %s " % basename(sys.argv[0]))
        print(";;;")

        # A tune distance delta is a 16 bits value encoding a factor [0..1[
        NSS.dump(self.ssg_deltas_fp, "ssg_tune_deltas", 2)

        # A SSG tune value is represented internally as a 24 bits fixed point value
        # abc:xyz, where abc and xyz are resp. 12bits integer and fractional parts
        # The tune's 24 bits (ab cx yz) are stored as two idependent buffers
        # abcx[notes] and yz[notes], to optimize access at runtime.

        # add missing/unreacheable octave for matching offset
        tunes = self.all_tunes_fp[0:12] + self.all_tunes_fp
        dists = self.all_ssg_dists[0:12] + self.all_ssg_dists

        NSS.dump([x & 0xFFFF for x in dists], "ssg_dists_lsb", 2, NSS.semitones, 12, 16)
        NSS.dump([x >> 8 for x in tunes], "ssg_tunes_msb", 2, NSS.semitones, 12, 16)
        NSS.dump([x & 0xFF for x in tunes], "ssg_tunes_lsb", 1, NSS.semitones, 12, 16)
        NSS.dump([x >> 16 for x in dists], "ssg_dists_msb", 1, NSS.semitones, 12, 16)


class FM(NSS):
    """Generator for precomputed FM note tables"""

    # Note on F-num formula
    #
    # From YM2610 doc: Fnum = freq * 144 * 2^20 / clock / 2^(block-1)
    # YM2610 doc and Furnace differ on the factor used in the formula:
    #   - YM2010:  144 * 2^20
    #   - Furnace: 9440540 * 2^4
    # see https://github.com/tildearrow/furnace/issues/2800
    #
    # A rounding is applied to get an integer F-num. Furnace doesn't round
    # the end-result of the formula above. Instead, it rounds an intermediate
    # value prior to dividing by 2^block.

    def __init__(self, clock):
        # YM2610 clock frequency for computations
        if clock == Clock.MVS:
            self._8M = 24000000 / 3
        else:
            self._8M = 24167829 / 3

        # Original Furnace data to validate generated precomputed data
        if clock == Clock.MVS:
            from fur_fm_mvs import furdata
        else:
            from fur_fm_aes import furdata
        self.furdata = furdata

        # FM base Fnum approximation (12:12 fixed point) for all semitones C-1..B-1
        # (the remaining octaves are just pre-multiplied in hardware by the YM2610,
        # so the precomputed table is kept minimal)
        self.all_fnums_fp = [self.fnum_fp(NSS.a4semitones[i]) for i in range(12)]
        # NOTE: an additional item just to compute the last value of the diff table below
        self.all_fnums_fp.append(self.fnum_fp(NSS.a4semitones[0]) * 2)

        # Tweaks: with our fixed-point approximation, we are slightly off from
        # what Furnace generates for a handful of semitones+pitch combinations.
        # By fine-tuning the fixed-point SSG tune approximation by a minuscule amount,
        # we can erase the small differences and stick exactly to Furnace values.
        if clock == Clock.MVS:
            all_fnums_fine_tuning = [1, 4, 0, 0, 0, 2, 1, 1, 0, 2, 3, 2, 2]
        else:
            all_fnums_fine_tuning = [0, 1, 0, 0, 0, 0, 0, 1, 2, 0, 0, 2, 3]
        for i, tuned in enumerate(all_fnums_fine_tuning):
            self.all_fnums_fp[i] += tuned

        # Distance between FM base Fnum for all semitones
        self.all_fm_dists = [self.all_fnums_fp[i + 1] - self.all_fnums_fp[i] for i in range(12)]
        # Additional item no longer needed after diff computation
        self.all_fnums_fp.pop()

        # Delta table for FM F-nums
        self.fm_deltas_fp = NSS.get_delta_table(lambda x: self.fnum_f(x))

    def freq(self, a4semitone_f):
        """Decimal frequency (floating point) for a decimal semitone (floating point)"""
        freq_f = NSS.A4TUNING * 2 ** ((NSS.a4semitone_f) / 12)
        return freq_f

    def fnum_f(self, a4semitone_f):
        """F-num (floating point) associated with a decimal semitone (floating point)"""
        c0semitone_f = a4semitone_f + 57
        block = int(c0semitone_f) // 12
        freq_f = NSS.A4TUNING * (2 ** (a4semitone_f / 12))
        divider = 9440540 * 2**4
        fnum_no_round = freq_f * divider * 2 / self._8M / (2 ** (block))
        return fnum_no_round

    def fnum_fp(self, a4semitone_f):
        """Approximated F-num (12:12 fixed point) associated with a decimal semitone (floating point)"""
        c0semitone_f = a4semitone_f + 57
        block = int(c0semitone_f) // 12
        freq_f = NSS.A4TUNING * (2 ** (a4semitone_f / 12))
        divider = 9440540 * 2**4
        fnum_no_round = freq_f * divider * 2 / self._8M / (2**block)
        fnum_fp = int(fnum_no_round * (2**12))
        return fnum_fp

    def round_fnum_fp(self, fnum_fp, block):
        """F-num (12:12 fixed point) to get an integer F-num"""
        round_f = 0.5 * (2**12) / (2**block)
        round_i = int(round_f)
        rounded_fnum_fp = fnum_fp + round_i
        return rounded_fnum_fp

    def fnum_i(self, a4semitone_f):
        """F-num (integer) associated with a decimal semitone (floating point)"""
        c0semitone_f = a4semitone_f + 57
        block = int(c0semitone_f) // 12
        freq_f = NSS.A4TUNING * (2 ** (a4semitone_f / 12))
        divider = 9440540 * 2**4
        # the Fnum is rounded following Furnace rounding (before dividing by 2^block)
        fnum_round = round(freq_f * divider * 2 / self._8M)
        fnum = fnum_round // (2**block)
        return fnum

    def fur_fnum_i(self, a4semitone_f):
        """F-num (integer) associated with a decimal semitone (floating point)"""
        c0semitone_f = a4semitone_f + 57
        block = int(c0semitone_f) // 12
        divider = 9440540
        fbase = NSS.A4TUNING * (2 ** ((c0semitone_f + 3) / 12))
        bf = round(fbase * divider / self._8M)
        fnum = bf // (2**block)
        return fnum

    def validate_all_pitches(self, pitches):
        NSS.compute_pitches(pitches, lambda p, e: self.validate_all_notes_for_pitch(p))

    def validate_all_notes_for_pitch(self, pitch):
        print(
            "pitch  note           bin      int fur rounded    nss_fp       diff    factor      delta    pitch_fp  rounded   fur\n"
        )
        errs = []
        # iterate over all notes considered in NSS (7 octaves)
        for s in range(0, 7 * 12):
            strg, diff = self.validate_note(s, pitch)
            print(strg)
            if diff:
                errs.append(strg)
        return errs

    def validate_note(self, s, pitch):
        substep = pitch / 128
        strg = ""

        # semitone offset from A-4
        a4semitone = NSS.a4semitones[s]
        # octave of semitone
        octave = (s // 12) + 1
        strg += "\x1b[2K\r[%03d] %02d %s" % (pitch, s, NSS.notename(a4semitone))

        # the value generated by Furnace, i.e. the value we have to match
        fur = self.furdata[pitch][s]

        # real pitched F-num, with right rounding (as computed by Furnace)
        real_pitched_fnum_i = self.fur_fnum_i(a4semitone + substep)
        real_str = NSS.chk(hex(real_pitched_fnum_i)[2:], hex(fur)[2:])
        strg += "  |  [%s] %3x %3s" % (bin(real_pitched_fnum_i)[2:].zfill(11), fur, real_str)

        # debug to make sure that rounding our fixed-point F-num representation works well
        dbg_pitched_fnum_fp = self.fnum_fp(a4semitone + substep)
        dbg_rounded_pitched_fnum_fp = self.round_fnum_fp(dbg_pitched_fnum_fp, octave)
        strg += " %s" % NSS.chk_fp(dbg_rounded_pitched_fnum_fp, real_pitched_fnum_i)

        # build the approximated position of this pitched semitone
        # (with the help of a fixed-point delta factor)

        # . start with the non-pitched fixed-point F-num for this semitone
        approx_fnum_fp = self.all_fnums_fp[s % 12]
        strg += "  |  %06x" % (approx_fnum_fp)

        # . then build the displacement from the delta factor
        bits = 16
        precision = 2**bits
        distance_to_next_approx_fnum_fp = self.all_fm_dists[s % 12]
        pitch_delta_fp = self.fm_deltas_fp[pitch]
        strg += "  | + %06x x 0.%04x" % (distance_to_next_approx_fnum_fp, pitch_delta_fp)
        distance_to_approx_pitched_fnum_fp = (distance_to_next_approx_fnum_fp * pitch_delta_fp) // precision
        approx_pitched_fnum_fp = approx_fnum_fp + distance_to_approx_pitched_fnum_fp
        strg += "  | + %06x = %06x" % (distance_to_approx_pitched_fnum_fp, approx_pitched_fnum_fp)

        # . at last, apply the Furnace rounding to get the NSS F-num
        approx_rounded_pitched_fnum_fp = self.round_fnum_fp(approx_pitched_fnum_fp, octave)
        strg += "  | %s" % NSS.chk_fp(approx_rounded_pitched_fnum_fp, real_pitched_fnum_i)

        # for comparison purpose, show the real F-num next to the NSS F-num
        strg += "  | %03x" % (real_pitched_fnum_i)

        nss_fnum_i = approx_rounded_pitched_fnum_fp >> 12
        return strg, nss_fnum_i != fur

    def dump_tables(self):
        hw = "MVS" if self._8M == 8000000 else "AES"
        print(";;; FM pitched note tables (%s) for nullsound, the ngdevkit sound driver" % hw)
        print(";;; Generated with %s " % basename(sys.argv[0]))
        print(";;;")

        # A fnum distance delta is a 16 bits value encoding a factor [0..1[
        NSS.dump(self.fm_deltas_fp, "fm_fnum_deltas", 2)

        # A FM F-num value is represented internally as a 23 bits fixed point value
        # abc:xyz, where abc and xyz are resp. 11bits integer and fractional parts
        # The tune's 23 bits (ab cx yz) are stored as two idependent buffers
        # abcx[notes] and yz[notes], to optimize access at runtime.
        NSS.dumpv(self.all_fnums_fp, "fm_fnums", NSS.semitones, 3)
        NSS.dumpv(self.all_fm_dists, "fm_dists", NSS.semitones, 3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate precomputed note tables for YM2610 channels.")

    parser.add_argument(
        "-p",
        "--pitch",
        type=int,
        nargs="+",
        default=list(range(128)),
        help="all pitches from base notes. Defaults to 0-127",
    )
    parser.add_argument(
        "-t",
        "--type",
        type=ChannelType,
        choices=ChannelType,
        default=ChannelType.FM,
        help="channel type. Defaults to fm",
    )
    parser.add_argument(
        "-c", "--clock", type=Clock, choices=Clock, default=Clock.MVS, help="hardware target. Defaults to mvs"
    )
    parser.add_argument("--dump", action="store_true", help="print generated tables. Defaults to false")

    arguments = parser.parse_args()

    channel_class = SSG if arguments.type == ChannelType.SSG else FM
    channel = channel_class(arguments.clock)

    if arguments.dump:
        channel.dump_tables()
    else:
        channel.validate_all_pitches(arguments.pitch)
