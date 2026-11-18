;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024-2026 Damien Ciabrini
;;; This file is part of ngdevkit
;;;
;;; ngdevkit is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU Lesser General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;; License, or (at your option) any later version.
;;;
;;; ngdevkit is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU Lesser General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General Public License
;;; along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

;;; Modulation effects (vibrato/tremolo), common to all channel types
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"
        .include "pipeline.inc"


        .equ    VIBRATO_PRECALC_SIZE, 64
        .equ    TREMOLO_PRECALC_SIZE, 128



        .area  CODE


;;; Enable vibrato effect for the current channel
;;;
;;; @param[in] ix: state for channel
;;; @param[in] de: offset to the note or vol FX state
;;; @param[in] hl: NSS arguments in memory
;;; @memory
;;;   hl | speed (4bits) and depth (4bits)
;;;
;;; @return parse next opcode
;;;
;;; @modified af, iy
;;;
vibrato_init::
        ;; iy: FX state for channel
        push    ix
        pop     iy
        add     iy, de

        ;; if vibrato was in use, keep the current vibrato pos
        bit     BIT_FX_VIBRATO, DATA_FX(iy)
        jp      nz, _post_vibrato_pos
        ;; else reset vibrato sine pos
        ld      MODULATE_POS(iy), #0
_post_vibrato_pos:
        ;; enable vibrato FX
        set      BIT_FX_VIBRATO, DATA_FX(iy)

        ;; speed
        ld      a, (hl)
        rra
        rra
        rra
        rra
        and     #0xf
        ld      MODULATE_SPEED(iy), a

        ;; depth, clamped to [1..16]
        ld      a, (hl)
        and     #0xf
        inc     a
        ld      MODULATE_DEPTH(iy), a

        inc     hl

        ;; pop the vol or note config
        pop     de

        ld      a, #1
        ret


;;; Scale a fixed point 8:8 value into x/16 fraction
;;;
;;; IN:
;;;   bc : distance [8:8 increment]
;;;    a : scale factor [1..16]
;;; OUT:
;;;    h : integer part of the scaled value
;;;    l : frcational part of the scaled value
;;;    e : carry bit from scaling operation
;;;
;;; @modified af, bc, hl, e
;;;
modulate_scale_increment:
        ;; hl: displacement = precalc * depth scaling
        sla     a
        jr      nc, _m_post_bit4
        add     hl, bc
_m_post_bit4:
        add     hl, hl
        add     a, a
        jr      nc, _m_post_bit3
        add     hl, bc
_m_post_bit3:
        add     hl, hl
        add     a, a
        jr      nc, _m_post_bit2
        add     hl, bc
_m_post_bit2:
        add     hl, hl
        add     a, a
        jr      nc, _m_post_bit1
        add     hl, bc
_m_post_bit1:
        ;; this 16bit shift might overflow now if the precalc is one full
        ;; note displacement (0x1000) and depth is full (0x10). Recall
        ;; the potential overflow bit in e
        add     hl, hl
        rl      e
        add     a, a
        jr      nc, _m_post_bit0
        add     hl, bc
_m_post_bit0:
        ret


;;; Update the vibrato for the current channel
;;; Vibrato oscillates the current fixed-point note's between the previous
;;; and the next semitones [-1.0..+1.0], and follows a sine wave.
;;; This function update the frequency by one step among the 64 steps
;;; defined in the sine wave.
;;;
;;; @param[in] ix: state for channel
;;; @param[in] iy: FX state for channel
;;;
;;; @modified af, bc, de, hl
;;;
eval_vibrato_step::
        ;; e: next vibrato pos
        ld      a, MODULATE_POS(iy)
        add     a, MODULATE_SPEED(iy)
        and     #(VIBRATO_PRECALC_SIZE-1)
        ld      MODULATE_POS(iy), a
        ;; e: offset for sine precalc
        sla     a
        ld      e, a
        ;; hl: pos in sine precalc
        ld      hl, #sine
        ld      a, l
        add     e
        ld      l, a

        ;; bc: displacement from sine precalc
        ld      c, (hl)
        inc     hl
        ld      b, (hl)

        ;; hl: displacement = precalc * depth scaling
_v_mul:
        ld      a, #0
        ld      l, a            ; precalc's 4 LSB
        ld      h, a            ; precalc's 4 MSB
        ld      e, a            ; precalc's 9th bit
        ld      d, a            ; precalc's sign

        ;; d: precalc sign
        sla     b
        rl      d
        srl     b

        ;; a effect depth clamped to [1..16] (5 bits)
        ld      a, MODULATE_DEPTH(iy)
        ;; TODO move shifts in the vibrato setup, and store bounds
        ;; as [0..15], to avoid shifts at every tick (FM and SSG)
        sla     a
        sla     a
        sla     a

        call    modulate_scale_increment

        ;; after scaling, h holds the floating part of the displacement
        ;; and e holds the 9th bit of the displacement
        ld      l, h
        ld      h, e

        ;; negate the position based on the precalc's sign
        bit     0, d
        jr      z, _v_post_sign
        xor     a
        sub     l
        ld      l, a
        sbc     a, a
        sub     h
        ld      h, a
_v_post_sign:

        ld      MODULATE_POS16(iy), l
        ld      MODULATE_POS16+1(iy), h

        ret


;;; Update the tremolo for the current channel
;;;
;;; @param[in] ix: state for channel
;;; @param[in] iy: FX state for channel
;;;
;;; @modified af, bc, de, hl
;;;
eval_tremolo_step::
        ;; e: next vibrato pos
        ld      a, MODULATE_POS(iy)
        add     a, MODULATE_SPEED(iy)
        and     #(TREMOLO_PRECALC_SIZE-1)
        ld      MODULATE_POS(iy), a
        ;; bc: offset for sine precalc
        ld      c, a
        ld      b, #0
        ;; hl: pos in sine precalc
        ld      hl, #tremolo_cosine
        add     hl, bc

        ;; bc: attenuation tremolo cosine precalc (4:4 fixed point)
        ld      c, (hl)
        xor     a
        ld      b, a

        ;; hl: placeholder for final scaled attenuation
        ld      h, a
        ld      l, a

        ;; a: effect depth clamped to [1..16] (5 bits)
        ld      a, MODULATE_DEPTH(iy)
        ;; TODO move shifts in the vibrato setup, and store bounds
        ;; as [0..15], to avoid shifts at every tick (FM and SSG)
        sla     a
        sla     a
        sla     a

        call    modulate_scale_increment

        ;; tremolo scaling doesn't touch carry, so only consider hl
        ld      MODULATE_POS16(iy), l
        ld      MODULATE_POS16+1(iy), h

        ret

;;;
;;; @ingroup nss_fx
;;; @{
;;;


;;; Enable vibrato for the current channel
;;;
;;; @param[in] hl: NSS arguments in memory
;;; @memory
;;;   hl | speed (4bits) and depth (4bits)
;;;
;;; @return parse next opcode
;;;
;;; @modified af, hl
;;;
vibrato::
        push    de
        ld      de, #NOTE_CTX
        jp      vibrato_init


;;; Disable vibrato for the current channel
;;;
;;; @return parse next opcode
;;;
;;; @modified af
;;;
vibrato_off::
        ;; disable FX
        res     BIT_FX_VIBRATO, NOTE_FX(ix)
        ;; since we disable the FX outside of the pipeline process
        ;; make sure to load this new note at next pipeline run
        set     BIT_LOAD_NOTE, PIPELINE(ix)
        ld      a, #1
        ret


;;; Enable tremolo for the current channel
;;;
;;; @param[in] hl: NSS arguments in memory
;;; @memory
;;;   hl | speed (4bits) and depth (4bits)
;;;
;;; @return parse next opcode
;;;
;;; @modified af, hl
;;;
tremolo::
        push    de
        ld      de, #VOL_CTX
        jp      vibrato_init


;;; Disable tremolo for the current channel
;;;
;;; @return parse next opcode
;;;
;;; @modified af
;;;
tremolo_off::
        ;; disable FX
        res     BIT_FX_VIBRATO, FX(ix)
        ;; since we disable the FX outside of the pipeline process
        ;; make sure to load this new note at next pipeline run
        set     BIT_LOAD_VOL, PIPELINE(ix)
        ld      a, #1
        ret


;;; @}
;;; 
