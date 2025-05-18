# NSS: music playback with nullsound streams

nullsound can play music modules composed with Furnace [1]. Those modules are processed by `nsstool` and converted into a format that can be played back easily on the Z80.

Internally, nullsound achieves music playback by reading a nullsound stream (NSS), which is its internal representation of an entire music, split into bytecodes that represent atomic actions (e.g. play a note, load an instrument, start a effect, wait some time...). Unlike VGM, NSS organizes the music by YM2610 channel and pattern for de-duplication, and bytecode is designed to yield efficient data storage.

This document details the current level of support for Furnace features in NSS. It also highlights the current differences between NSS and Furnace, to help you compose tracks that should play back nicely in nullsound.


## Currently supported Furnace features

* The supported Furnace module format is "Neo Geo MVS" (single chip, YM2610). Currently, "Neo Geo MVS (extended channel 2)" is not yet supported.

* When ADPCM-A or ADPCM-B instruments use samples encoded in `.wav` format, they are automatically converted to ADPCM by ngdevkit. Some details worth noting:

  - Right now, `nsstool` only supports `.wav` samples whose format is 16-bit PCM, mono channel. Additionally, samples used for ADPCM-A instruments are expected to be 18.5KHz. Automatic conversion of 8-bit PCM is not yet supported.

  - If an ADPCM-B sample is used for looping, make sure that the sample's length is a multiple of 512 sample units, otherwise you will hear popping artifacts. This is because on the YM2610, a single ADPCM-B sample unit is encoded as 4-bits, and sample playback can only start and end on 256 bytes boundaries.

* Instrument macros are currently only implemented for SSG instruments, with the following limitations:

  - Only the `sequence` macro type can used to configure SSG properties. Macro types `ADSR` and `LFO` are not supported and there is no plan to support them.

  - Within a sequence macro, each step is 1 tick long. That is, each time the YM2610 triggers an IRQ during music playback, a step of the macro is being evaluated. Unlike in Furnace, there is no native support in NSS for step length or step delay.

  - Macro looping is currently different from what Furnace allows. Currently, NSS groups property updates by steps. When the loop is reached, it starts again from the configured step, which means all properties are re-evaluated from this step. This means you can't have loops for two different properties. This is going to improve in the future to match Furnace's semantics.

  - SSG Auto-envelope feature is currently broken, SSG instruments using that feature can be processed by `nsstool`, but the resulting playback is invalid. Do not use it.

* If you use SSG in your Furnace module, and SSG instruments uses the volume envelope bit for the channel, be aware that this will prevent you from fading out your module while it's playing. This is because the YM2610 has no support in hardware to change the volume of the envelope generator.


## Currently supported Furnace FX

- 💚: Supported
- ⚠️: Partial support
- 💜: To do
- 🚫: No, not planned


## Volume

| FX   | Description                   | Status | Note |
|------|-------------------------------|--------|------|
| `0A` | Volume slide                  | 💚️     |      |
| `FA` | Fast volume slide             | 💜     |      |
| `F3` | Fine volume slide up          | 💜     |      |
| `F4` | Fine volume slide down        | 💜     |      |
| `F8` | Single tick volume slide up   | 💜     |      |
| `F9` | Single tick volume slide down | 💜     |      |
| `07` | Tremolo                       | 💜     |      |


## Pitch

| FX | Description                  | Status | Note |
|----|------------------------------|--------|------|
| E5 | Set pitch                    | 💚     |      |
| 01 | Pitch slide up               | 💚     |      |
| 02 | Pitch slide down             | 💚     |      |
| F1 | Single tick pitch slide up   | 💜     |      |
| F2 | Single tick pitch slide down | 💜     |      |
| 03 | Portamento                   | 💚     |      |
| E1 | Note slide up                | 💚     |      |
| EA | Toggle legato                | 💜     |      |
| E2 | Note slide down              | 💚     |      |
| E6 | Quick legato (compatibility) | 🚫     |      |
| E8 | Quick legato up              | 💚     |      |
| E9 | Quick legato down            | 💚     |      |
| 00 | Arpeggio                     | 💚     |      |
| E0 | Set arpeggio speed           | 💚     |      |
| 04 | Vibrato                      | 💚     |      |
| E3 | Set vibrato direction        | 🚫     |      |
| E4 | Set vibrato rang             | 🚫     |      |


## Panning

| FX | Description                      | Status | Note |
|----|----------------------------------|--------|------|
| 08 | Set panning                      | 💚     |      |
| 88 | Set rear panning                 | 🚫     |      |
| 81 | Set volume of left channel       | 🚫     |      |
| 82 | Set volume of right channel      | 🚫     |      |
| 89 | Set volume of rear left channel  | 🚫     |      |
| 8A | Set volume of rear right channel | 🚫     |      |
| 80 | Set panning (linear)             | 💚     |      |


## Time

| FX | Description                   | Status | Note |
|----|-------------------------------|--------|------|
| 09 | Set speed/groove              | 💚     |      |
| 0F | Set speed 2                   | 💚     |      |
| Cx | Set tick rate                 | 🚫     |      |
| F0 | Set BPM                       | 🚫     |      |
| FD | Set virtual tempo numerator   | 🚫     |      |
| FE | Set virtual tempo denominator | 🚫     |      |
| 0B | Jump to order                 | 💚     |      |
| 0D | Jump to next pattern          | 💜     |      |
| FF | Stop song                     | 💚     |      |


## Note

| FX | Description   | Status | Note |
|----|---------------|--------|------|
| 0C | Retrigger     | 💚     |      |
| EC | Note cut      | 💚     |      |
| ED | Note delay    | 💚     |      |
| FC | Note release  | 💜     |      |
| E7 | Macro release | 🚫     |      |


# ADPCM Sample offset

| FX | Description                     | Status | Note |
|----|---------------------------------|--------|------|
| 90 | Set sample offset (first byte)  | 💜     |      |
| 91 | Set sample offset (second byte) | 💜     |      |
| 92 | Set sample offset (third byte)  | 💜     |      |


# Other

| FX | Description                 | Status | Note |
|----|-----------------------------|--------|------|
| EB | Set LEGACY sample mode bank | 🚫     |      |
| EE | Send external command       | 💜     |      |
| F5 | Disable macro               | 🚫     |      |
| F6 | Enable macro                | 🚫     |      |
| F7 | Restart macro               | 🚫     |      |



[1] https://github.com/tildearrow/furnace
