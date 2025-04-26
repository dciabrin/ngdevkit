# Slide FX semantics

## pitch slide (01xx / 02xx)

Move current note up or down

  - FX specifies a direction (up / down), and a decimal increment
  - slide stops when explicitely disabled (01.. / 02..) or when another slide FX is configured
  - slide is relative to the note currently in use
  - As soon as the FX is applied, it adds to the current note's decimal position
  - When changing current note when slide is in progress, the FX continues from this new current note's decimal position

```
E-40A..0101
...........
...........
...........
...........
D-40A......
```

## portamento (03xx)

Move current note up or down towards a target note

  - FX specifies a speed only, and assumes the target note is the note specified in the score's current line
  - portamento continues until the target note is reached, or when another slide FX is configured
  - portamento direction (up/down) is determined based on the current note
  - When changing current note while portamento is in progress, this only changes the portamento target (and thus the portamento direction)

ex: portamento from C5 to G-5

```
C-50A......
G-50A..0301
...........
...........
...........
...........
```

ex: portamento from C5 to G5, increase speed to target after started

```
C-50A......
G-50A..0301
...........
...........
G-50A..0308
...........
```

## note slide (E1xx / E2xx)

Move current note up or down by a number of semitones

  - FX is effectively a portamento FX whose target is relative to the note currently in use
  - The remaining semantics is the same as a portamento effect

ex: slide from A-5 to B-5, and set next note to B-5 (end will be B-5 after portamento finishes)

```
A-50A......
...........
...........
.......E122
B-50A......
...........
```
