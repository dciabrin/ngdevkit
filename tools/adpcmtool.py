#!/usr/bin/env python3
# Copyright (c) 2020 Damien Ciabrini
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

"""adpcmtool.py - Convert WAV to YM2610 ADPCM-A

Inspired by freem's adpcma encoder tool
"""

import struct
import sys
import argparse
import wave


VERBOSE = False


def error(str):
    sys.exit("error: "+str)


def dbg(str):
    if VERBOSE:
        print(str, file=sys.stderr)


# YM2610 ADPCM-A is a variation of the standard IMA ADPCM
# encoding [1], with the lookup tables and clamping values
# adapted to encode a 12bit input sample into a 4bit
# output (1 sign + 3quantized values). Its very close to
# the Dialogic ADPCM implementation [2].
#
# [1] https://wiki.multimedia.cx/index.php/IMA_ADPCM
# [2] https://wiki.multimedia.cx/index.php/Dialogic_IMA_ADPCM
#
class ym2610_adpcma(object):

    # Adaptive step size for the quantizer; the step size grows
    # exponentially: size(n) = 1*1 x size(n-1). There are
    # 49 steps, which is sufficient to encode a 12bits input.
    step_size = [
        16,   17,   19,   21,   23,   25,   28,
        31,   34,   37,   41,   45,   50,   55,
        60,   66,   73,   80,   88,   97,  107,
        118, 130,  143,  157,  173,  190,  209,
        230, 253,  279,  307,  337,  371,  408,
        449, 494,  544,  598,  658,  724,  796,
        876, 963, 1060, 1166, 1282, 1411, 1552
        ]

    # Index adjustment in the step size table based on an
    # encoded ADPCM input (4bits). The adjustment only
    # depends on the quantized magnitude (first 3 bits),
    # the 8 entries are duplicated for simplicity.
    step_adj = [
        -1, -1, -1, -1, 2, 5, 7, 9,
        -1, -1, -1, -1, 2, 5, 7, 9
    ]

    def __init__(self):
        # set initial adpcma codec state
        self.reset()

    def reset(self):
        # encoder: index in the adaptive step size
        self.enc_index = 0
        # encoder: previous predicted sample
        self.enc_previous_predicted12 = 0
        # decoder: index in the adaptive step size
        self.dec_index = 0
        # decoder: previous decoded sample
        self.dec_previous_sample12 = 0

    def _encode_sample(self, sample12):
        previous_predicted12 = self.enc_previous_predicted12
        diff = sample12 - previous_predicted12

        # quantize the diff w.r.t current step size
        threshold = self.step_size[self.enc_index]

        # encode sign (bit4)
        if diff >= 0:
            adpcm4 = 0
        else:
            adpcm4 = 0b1000
            diff = -diff

        # encode diff magniture
        # bit3 for stepsize
        if diff >= threshold:
            adpcm4 |= 0b0100
            diff -= threshold

        # bit2 for stepsize/2
        threshold >>= 1
        if diff >= threshold:
            adpcm4 |= 0b0010
            diff -= threshold

        # bit1 for stepsize/4
        threshold >>= 1
        if diff >= threshold:
            adpcm4 |= 0b0001

        # predict the next sample and the next quantization step size
        predicted12 = self._decode_sample(adpcm4)
        self.enc_previous_predicted12 = predicted12

        index = self.enc_index + self.step_adj[adpcm4]
        self.enc_index = max(0, min(index, 48))

        return adpcm4

    def _decode_sample(self, adpcm4):
        # retrieve the diff based on quantization magnitude
        # diff = m3.stepsize + m2.stepsize/2 + m1.stepsize/4 + stepsize/8
        # stepsize/8 is always added to account to counter precision loss
        step_size = self.step_size[self.dec_index]
        magnitude = adpcm4 & 0x7
        diff = ((2*magnitude + 1) * step_size) >> 3
        if adpcm4 & 0x8:
            diff = -diff

        # record the decoded state for the next decode
        previous12 = self.dec_previous_sample12
        sample12 = previous12 + diff
        sample12 = max(-2048, min(sample12, 2047))
        self.dec_previous_sample12 = sample12

        index = self.dec_index + self.step_adj[adpcm4]
        self.dec_index = max(0, min(index, 48))

        return sample12

    def encode(self, pcm12s, pad=True):
        self.reset()
        adpcms = [self._encode_sample(s) for s in pcm12s]
        pattern = [0b0000, 0b1000] if adpcms[-1] < 0 else [0b1000, 0b0000]
        if len(adpcms) % 2 == 1:
            adpcms += pattern[:1]
        if pad:
            # YM2610 can only play ADPCM-A samples whose size in
            # samples is a multiple of 512. However each decoded
            # sample always adds/removes 1/8 the step size to the
            # previous sample. So in order to pad with silence,
            # so we must alternate 0 and -0 in the output.
            length = 512 - (len(adpcms) % 512)
            padding = pattern * (length >> 1)
            adpcms += padding
        return adpcms

    def decode(self, adpcms):
        self.reset()
        # TODO: remove trailing padding if detected
        return [self._decode_sample(s) for s in adpcms]


def encode(input, output):
    dbg("Trying to encode input file %s" % input)

    try:
        w = wave.open(input, 'rb')
        # input sanity checks
        if w.getnchannels() > 1:
            error("Only mono WAV file is supported")
        if w.getsampwidth() != 2:
            error("Only 16bits per sample is supported")
        if w.getcomptype() != 'NONE':
            error("Only uncompressed WAV file is supported")
        rate = w.getframerate()
        if rate != 18500:
            dbg("Input framerate %s differs from 18500, playback will sound different" % rate)
        nframes = w.getnframes()
        rawdata = w.readframes(nframes)
    except FileNotFoundError:
        error("%s does not exist" % input)
    except wave.Error:
        dbg("Input is not a valid WAV file, assume it is a RAW file")
        # if we end up here, we know the file exists and is readable
        with open(input, 'rb') as f:
            rawdata = f.read()
    except Exception as e:
        error("Unexpected error while reading %s: %s" % (input, e))
    else:
        w.close()

    insize = len(rawdata)
    dbg("Input is %s bytes long, or %d PCM samples" % (insize, insize >> 1))

    # downscale signed 16bits input to 12bits, and encode to 4bits ADPCM
    samples = struct.unpack('<%dh' % (len(rawdata) >> 1), rawdata)
    samples12 = [s >> 4 for s in samples]
    codec = ym2610_adpcma()
    adpcms = codec.encode(samples12)

    # adpcm encoding => two adpcm samples per byte
    # YM2610 output is always a multiple of 256
    outsize = (insize >> 1) >> 1
    paddingsize = (((outsize + 255) >> 8) << 8) - outsize
    dbg("Encoded ADPCM output is %d bytes long, Including %d bytes "
        "of padding for YM2610 boundaries" % (outsize + paddingsize, paddingsize))

    dbg("Saving ADPCM-A output to file %s" % output)

    # pack the ADPCM nibbles and write the output
    a2 = [(adpcms[i] << 4 | adpcms[i+1]) for i in range(0, len(adpcms), 2)]
    with open(output, 'wb') as o:
        o.write(bytes(a2))


def decode(input, output):
    dbg("Trying to decode ADPCM-A input file %s" % input)

    try:
        with open(input, 'rb') as f:
            rawdata = f.read()
    except FileNotFoundError:
        error("%s does not exist" % input)
    except Exception as e:
        error("Unexpected error while reading %s: %s" % (input, e))

    insize = len(rawdata)
    dbg("Input is %s bytes long, or %d ADPCM samples" % (insize, insize << 1))

    # decode ADPCM samples and upsample them back to 16bits
    pairs = [(d >> 4, d & 0b1111) for d in rawdata]
    samples4 = list(sum(pairs, ()))
    codec = ym2610_adpcma()
    pcm12 = codec.decode(samples4)
    pcm16 = [s << 4 for s in pcm12]
    print(pcm16)
    print(len(pcm16))
    sys.exit(0)
    raw16 = struct.pack('<%dh' % len(pcm16), *pcm16)

    dbg("Saving WAV output to file %s" % output)

    # pack the ADPCM nibbles and write the output
    w = wave.open(output, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(18500)
    w.setnframes(len(pcm16))
    w.writeframes(raw16)
    w.close()


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description='YM2610 ADPCM-A audio converter.')

    paction = parser.add_argument_group('action')
    pmode = paction.add_mutually_exclusive_group(required=True)
    pmode.add_argument('-e', '--encode', action='store_true',
                       help='encode a input WAV file into ADPCM-A')
    pmode.add_argument('-d', '--decode', action='store_true',
                       help='decode raw ADPCM-A input into a WAV file')

    parser.add_argument('FILE', help='file to process')
    parser.add_argument('-o', '--output', required=True,
                        help='name of output file')

    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true',
                        default=False, help='print details of processing')

    arguments = parser.parse_args()
    VERBOSE = arguments.verbose
    if arguments.encode:
        encode(arguments.FILE, arguments.output)
    else:
        decode(arguments.FILE, arguments.output)


if __name__ == '__main__':
    main()
