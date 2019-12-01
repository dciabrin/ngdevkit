/* 
 * Header for C development on Neo Geo
 * Copyright (c) 2015-2019 Damien Ciabrini
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

#ifndef __NGDEVKIT_NEOGEO_H__

typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef signed short   s16;
typedef unsigned int   u32;
typedef signed int     s32;

#define ADDR_FIXMAP	0x7000

#define REG_VRAMADDR	((volatile u16*)0x3c0000)
#define REG_VRAMRW	((volatile u16*)0x3c0002)
#define REG_VRAMMOD	((volatile u16*)0x3c0004)

#define MMAP_PALBANK1	((volatile u16*)0x400000)

#define REG_WATCHDOGW   ((volatile u8*)0x300001)

#define REG_P1CNT       ((volatile u8*)0x300000)

#endif /* __NGDEVKIT_NEOGEO_H__ */
