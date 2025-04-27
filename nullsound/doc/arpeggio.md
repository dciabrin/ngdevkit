# Arpeggio FX semantics

## arpeggio (00xx)

Play a 3-note chord in succession, each note separated by a fixed number of ticks

  - The first note of the chord is the currently configured note
  - FX specifies the 2nd and 3rd note to play, as a positive semitone offset
  - arpeggio stops when explicitely disabled (01..)
  - By default, there are two ticks between two notes
  - As soon as the FX is applied, it adds to the current note's decimal position
  - When changing current note when slide is in progress, the chord resets to the first note
  - When an arpeggio in the middle of the chord, the change is effective directly after the configured amount of ticks is reached to play the next note.

```
E-40A..0037
...........
D-40A......
```

## arpeggio speed (e0xx)

Set the number of ticks between two note of the chord

  - minimum speed is 1

ex: portamento from C5 to G-5

```
.......E004
G-50A..0037
...........
...........
```
