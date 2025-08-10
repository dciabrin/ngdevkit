/*
 * BIOS utility functions
 * Copyright (c) 2025 Damien Ciabrini
 * This file is part of ngdevkit
 *
 * ngdevkit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * ngdevkit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __NULLBIOS_UTILS_H__
#define __NULLBIOS_UTILS_H__

#define WITH_BACKUP_RAM_RW(x) {                   \
    __asm__ volatile ("move.b  %d0, 0x3a001d.l"); \
    x                                             \
    __asm__ volatile ("move.b  %d0, 0x3a000d.l"); \
    }

#define CC_CLEAR_X_FLAG()                                        \
    do {                                                         \
        u8 tmp;                                                  \
        __asm__ volatile ("sub.b %0, %0" : "=r" (tmp) : : "cc"); \
    } while (0)

#define SUB_BCD(x, y)        \
    __asm__ ("sbcd   %1, %0" \
             : "+d" ((x))    \
             : "d" ((y))     \
             : "cc")

#define ADD_BCD(x, y)        \
    __asm__ ("abcd   %1, %0" \
             : "+d" ((x))    \
             : "d" ((y))     \
             : "cc")

#define SET_CONST_W(var, cst) \
__asm__ ("move.w %1, %0" : "=r" (var) : "i" (cst) :);

#define SET_CONST_ADDR(var, cst) \
__asm__ ("movea.l %1, %0" : "=r" (var) : "i" (cst) :);

#endif /* __NULLBIOS_UTILS_H__ */
