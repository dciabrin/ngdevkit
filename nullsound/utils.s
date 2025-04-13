;;;
;;; nullsound - modular sound driver
;;; Copyright (c) 2024-2025 Damien Ciabrini
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

;;; Utility functions used by various nullsound subsystems
;;;

        .module nullsound

        .include "ym2610.inc"
        .include "struct-fx.inc"


        .area  CODE

;;; multiply a 24bit integer by a 8bit integer, yielding a 32bit integer
;;; unrolled loop for slightly faster operation
;;; ----
;;; IN:
;;;    bc:de : 24bits multiplicand
;;;    a: multiplier
;;; OUT:
;;;    hl:iy : multiplied number
;;; bc, de, hl, iy modified
mul_int24_by_int8:
        ;; setup output
        ld      hl, #0
        ld      iy, #0

        ;; hliy += bcde*a7
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a6
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a5
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a4
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a3
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a2
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a1
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ;; hliy += bcde*a0
        sla     e
        rl      d
        rl      c
        rl      b
        rra
        jr      nc, .+6
        add     iy, de
        adc     hl, bc

        ret


;;; scale a 24bit integer i by a 16bit factor in [0..1[
;;; the scaling yields a 24bit integer in [0..i[
;;; ----
;;; IN:
;;;    cde: 24bit integer
;;;     hl: 16bit scaling factor
;;; OUT:
;;;    deb: scaled 24bit integer
;;; bc, de, hl, iy modified
scale_int24_by_factor16:
        ld      b, #0
        push    de              ; +distance __:16
        push    bc              ; +distance _8:__
        push    hl              ; +delta

        ;; a: delta's LSB
        ld      a, l

        ;; hl:iy : 1st part of the multiplication (with delta's LSB)
        call    mul_int24_by_int8

        ;; a: delta's MSB
        pop     bc              ; -delta
        ld      a, b

        ;; pop multiplicand, prepare for 2nd part of the multiplication
        pop     bc              ; -distance _8:__
        pop     de              ; -distance __:16

        ;; save 1st part
        push    iy              ; +mul1 __:16
        push    hl              ; +mul1 16:__

        ;; hl:iy : 2nd part of the multiplication (with delta's MSB)
        call    mul_int24_by_int8

        ;; pop and shift 1st part (>>8) for merging with 2nd part
        pop     bc              ; -mul1 16:__
        pop     de              ; -mul1 __:16
        ld      e, d
        ld      d, c
        ld      c, b
        ld      b, #0

        ;; hl:iy : final multiplication result: mul2 + (mul1>>8)
        add     iy, de
        adc     hl, bc

        ;; discard 8bits LSB and move final 24bits into de:b
        ex      de, hl
        push    iy
        pop     bc

        ret
