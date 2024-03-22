#!/usr/bin/env python3
# Copyright (c) 2020-2023 Damien Ciabrini
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

"""adpcmtool.py - YM2610 ADPCM-A and ADPCM-B audio converter

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
# adapted to encode a 12-bits input sample into a 4-bits
# output (1 bit sign + 3 bits quantized diff). It's very close
# to the Dialogic ADPCM implementation [2].
#
# [1] https://wiki.multimedia.cx/index.php/IMA_ADPCM
# [2] https://wiki.multimedia.cx/index.php/Dialogic_IMA_ADPCM
#
class ym2610_adpcma(object):

    # Adaptive step size for the quantizer; the step size grows
    # exponentially: size(n) = 1.1 * size(n-1). There are
    # 49 steps, which is sufficient to encode a 12-bits input.
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
    # encoded ADPCM input's magnitude (3 bits).
    step_adj = [
        -1, -1, -1, -1, 2, 5, 7, 9,
    ]

    def __init__(self):
        # set initial adpcma codec state
        self.reset()

    def reset(self):
        # index in the adaptive step size
        self.state_step_index = 0
        # previous decoded sample
        self.state_sample12 = 0

    def _encode_sample(self, sample12):
        # diff between sample to encode and codec's current state
        diff = sample12 - self.state_sample12

        # quantize the diff w.r.t codec's current state
        sign = 0b1000 if (diff < 0) else 0
        magnitude = 0
        diff = abs(diff)
        threshold = self.step_size[self.state_step_index]
        # bit 3 for stepsize
        if diff >= threshold:
            magnitude |= 0b0100
            diff -= threshold
        # bit 2 for stepsize/2
        threshold >>= 1
        if diff >= threshold:
            magnitude |= 0b0010
            diff -= threshold
        # bit 1 for stepsize/4
        threshold >>= 1
        if diff >= threshold:
            magnitude |= 0b0001

        adpcm4 = sign | magnitude

        # update the codec's state: keep track of the processed
        # sample after its quantization, and prepare the next step size.
        # This is equivalent to decoding the quantized sample
        _ = self._decode_sample(adpcm4)

        return adpcm4

    def _decode_sample(self, adpcm4):
        # current step size based on last decode state
        step_size = self.step_size[self.state_step_index]

        # sign of the compressed adpcm nibble
        sign = adpcm4 & 8

        # magnitude of the compressed adpcm nibble
        magnitude = adpcm4 & 7

        # reconstruct the 16-bits diff from the magnitude and the step size
        # diff = m3.stepsize + m2.stepsize/2 + m1.stepsize/4 + stepsize/8
        # stepsize/8 is always added to account for precision loss
        quantized_diff = ((2*magnitude + 1) * step_size) >> 3
        if sign:
            quantized_diff = -quantized_diff

        # generate the new sample from codec's current state
        decoded_sample12 = self.state_sample12 + quantized_diff
        decoded_sample12 = max(-2048, min(decoded_sample12, 2047))

        # adjust the step index to use for the next adpcm sample to decode
        new_step_index = self.state_step_index + self.step_adj[magnitude]
        new_step_index = max(0, min(new_step_index, 48))

        # update codec's state
        self.state_sample12 = decoded_sample12
        self.state_step_index = new_step_index

        return decoded_sample12

    def encode(self, pcm16s):
        self.reset()
        # ADPCM-A encodes 12-bits samples, so downscale the input first
        pcm12s = [s >> 4 for s in pcm16s]
        # YM2610 only plays back multiples of 256 bytes
        # (512 adpcm samples). If the input is not aligned, add some padding
        ceil = ((len(pcm12s)+511)//512)*512;
        padding = [0] * (ceil - len(pcm12s))
        adpcms = [self._encode_sample(s) for s in pcm12s+padding]
        return adpcms

    def decode(self, adpcm4s):
        self.reset()
        # ADPCM-A decodes 12-bits samples, so upscale the output to wav format
        pcm12s = [self._decode_sample(s) for s in adpcm4s]
        pcm16s = [s << 4 for s in pcm12s]
        return pcm16s



# YM2610 ADPCM-B encodes 16-bits input data into a series of
# 4-bits output (1 bit sign + 3 bits quantized diff).
# Unlike ADPCM-A, the change in step size is only determined
# via a single lookup table that is fine-tuned to scale the
# step based on the width of the quantized diff.
# ADPCM-B specs and reference encoder are detailed in the
# YM2608 application manual [1]
#
# [1] https://www.vgmpf.com/Wiki/images/d/de/YM2608_Manual_(Translated).pdf
#
class ym2610_adpcmb(object):
    # step size adjustment table for an ADPCM sample (4 bits)
    # the table returns a scaling factor (between 90% to 240%) for the
    # next step size, based on the ADPCM sample's magnitude (first 3 bits)
    step_table = [
        57, 57, 57, 57, 77, 102, 128, 153,
    ]

    def __init__(self):
        # set initial ADPCM-B codec state
        self.reset()

    def reset(self):
        # index in the adaptive step size
        self.state_step_size = 127
        # previous decoded sample
        self.state_sample16 = 0

    def _encode_sample(self, sample16):
        # current step size based on last decode state
        step_size = self.state_step_size

        # diff between sample to encode and codec's current state
        diff = sample16 - self.state_sample16

        # quantize the diff w.r.t codec's current state
        magnitude = (abs(diff) << 16) // (step_size << 14)
        magnitude = min(magnitude, 7)
        sign = 0b1000 if (diff < 0) else 0

        adpcm4 = sign | magnitude

        # update the codec's state: keep track of the processed
        # sample after its quantization, and prepare the next step size.
        # This is equivalent to decoding the quantized sample
        _ = self._decode_sample(adpcm4)

        return adpcm4

    def _decode_sample(self, adpcm4):
        # current step size based on last decode state
        step_size = self.state_step_size

        # sign of the compressed adpcm nibble
        sign = adpcm4 & 8

        # magnitude of the compressed adpcm nibble
        magnitude = adpcm4 & 7

        # reconstruct the 16bits diff from the magnitude and the step size
        # diff = m[3]*stepsize + m[2]*stepsize/2 + m[1].stepsize/4 + stepsize/8
        # stepsize/8 is always added to account for precision loss
        quantized_diff = ((2*magnitude + 1) * step_size) >> 3
        if sign:
            quantized_diff = -quantized_diff

        # generate the new sample from codec's current state
        decoded_sample16 = self.state_sample16 + quantized_diff
        decoded_sample16 = max(-32768, min(decoded_sample16, 32767))

        # adjust the step size to use for the next adpcm sample to decode
        new_step_size = (step_size * self.step_table[magnitude]) >> 6
        new_step_size = max(127, min(new_step_size, 24576))

        # update codec's state
        self.state_sample16 = decoded_sample16
        self.state_step_size = new_step_size

        return decoded_sample16

    def encode(self, pcm16s):
        self.reset()
        # YM2610 only plays back multiples of 256 bytes
        # (512 adpcm samples). If the input is not aligned, add some padding
        ceil = ((len(pcm16s)+511)//512)*512;
        padding = [0] * (ceil - len(pcm16s))
        adpcms = [self._encode_sample(s) for s in list(pcm16s)+padding]
        return adpcms

    def decode(self, adpcm4s):
        self.reset()
        pcm16s = [self._decode_sample(s) for s in adpcm4s]
        return pcm16s


def encode(input, output, codec):
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
        wavrate = w.getframerate()
        if isinstance(codec, ym2610_adpcma) and int(wavrate) != 18500:
            dbg("Input framerate %s differs from 18500, playback will sound different" % wavrate)
        nframes = w.getnframes()
        rawdata = w.readframes(nframes)
    except FileNotFoundError:
        error("%s does not exist" % input)
    except wave.Error as e:
        dbg("Input is not a valid WAV file, assume it is a RAW file")
        # if we end up here, we know the file exists and is readable
        with open(input, 'rb') as f:
            rawdata = f.read()
    except Exception as e:
        error("Unexpected error while reading %s: %s" % (input, e))
    else:
        w.close()

    insize = len(rawdata)
    samples = struct.unpack('<%dh' % (insize >> 1), rawdata)
    dbg("Input is %s bytes long, or %d PCM samples" % (insize, insize >> 1))
    # encode input 16-bits samples into ADPCM-A or ADPCM-B 4-bits samples
    adpcms = codec.encode(list(samples))
    # pack the resulting adpcm samples into bytes (2 samples per byte)
    adpcms_packed = [(adpcms[i] << 4 | adpcms[i+1]) for i in range(0, len(adpcms), 2)]
    outsize = len(adpcms_packed)
    paddingsize = (len(adpcms)-len(samples)) >> 1
    dbg("Encoded ADPCM output is %d bytes long, Including %d bytes "
        "of padding for YM2610 boundaries" % (outsize, paddingsize))

    dbg("Saving ADPCM output to file %s" % output)
    with open(output, 'wb') as o:
        o.write(bytes(adpcms_packed))


def decode(input, output, codec, samplerate):
    dbg("Trying to decode ADPCM input file %s" % input)

    try:
        with open(input, 'rb') as f:
            rawdata = f.read()
    except FileNotFoundError:
        error("%s does not exist" % input)
    except Exception as e:
        error("Unexpected error while reading %s: %s" % (input, e))

    insize = len(rawdata)
    adpcm4s = []
    for d in rawdata:
        adpcm4s.append(d >> 4)
        adpcm4s.append(d & 0b1111)
    dbg("Input is %s bytes long, or %d ADPCM samples" % (insize, len(adpcm4s)))

    # decode ADPCM samples to signed 16-bits output
    pcm16s = codec.decode(adpcm4s)
    raw16s = struct.pack('<%dh' % len(pcm16s), *pcm16s)

    dbg("Saving WAV output to file %s" % output)
    w = wave.open(output, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(samplerate)
    w.setnframes(len(pcm16s))
    w.writeframes(raw16s)
    w.close()


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(
        description='YM2610 ADPCM-A and ADPCM-B audio converter')

    pcodec = parser.add_argument_group('codec')
    pmode = pcodec.add_mutually_exclusive_group()
    pmode.add_argument('-a', '--adpcma', action='store_const',
                       const='a', dest='codec', default='a',
                       help='encode and decode with ADPCM-A codec')
    pmode.add_argument('-b', '--adpcmb', action='store_const',
                       const='b', dest='codec',
                       help='encode and decode with ADPCM-B codec')

    paction = parser.add_argument_group('action')
    pmode = paction.add_mutually_exclusive_group(required=True)
    pmode.add_argument('-e', '--encode', action='store_true',
                       help='encode a input WAV file into ADPCM')
    pmode.add_argument('-d', '--decode', action='store_true',
                       help='decode raw ADPCM input into a WAV file')

    parser.add_argument('FILE', help='file to process')
    parser.add_argument('-o', '--output', required=True,
                        help='name of output file')

    parser.add_argument('-r', '--rate',
                        type=int,
                        help='set sample rate of decoded ADPCM-B')

    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true',
                        default=False, help='print details of processing')

    arguments = parser.parse_args()
    VERBOSE = arguments.verbose

    codec = ym2610_adpcma() if arguments.codec == 'a' else ym2610_adpcmb()

    if arguments.rate == None:
        samplerate = 18500 if arguments.codec == 'a' else 44100
    else:
        samplerate = arguments.rate

    if arguments.encode:
        encode(arguments.FILE, arguments.output, codec)
    else:
        decode(arguments.FILE, arguments.output, codec, samplerate)


if __name__ == '__main__':
    main()
