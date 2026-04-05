/*
 * Private utility functions, not meant to be included directly
 * Copyright (c) 2026 Damien Ciabrini
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

#ifndef __NGDEVKIT__UTILS_H__
#define __NGDEVKIT__UTILS_H__


/** Allow to preserve a specific set of register prior to calling
 * calling a function. This can bee handy when the called function
 * does not follow the caller/callee-safe convention.
 */
#define __SAVE_REGS_AND_CALL(regs, fun) \
    __asm__ volatile ( \
                       "movem.l " regs ",%%sp@-\n" \
                       "jsr %m0.l\n" \
                       "movem.l %%sp@+, " regs "\n" \
                       : /* no output */ \
                       : "m" (fun) /* input */ \
                       : "d0", "d1", "a0", "a1" /* clobbers */ \
                       );


#endif /* __NGDEVKIT__UTILS_H__ */
