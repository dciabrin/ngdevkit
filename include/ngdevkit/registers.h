/*
 * Memory-mapped Neo Geo registers
 * Copyright (c) 2015-2020 Damien Ciabrini
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

#ifndef __NGDEVKIT_REGISTERS_H__
#define __NGDEVKIT_REGISTERS_H__

#include <ngdevkit/types.h>

/* Video RAM addresses */
#define ADDR_SCB1	0
#define ADDR_SCB2	0x8000
#define ADDR_SCB3	0x8200
#define ADDR_SCB4	0x8400
#define ADDR_FIXMAP	0x7000

/* Video registers */
#define REG_VRAMADDR	((u16*)0x3c0000)
#define REG_VRAMRW	((u16*)0x3c0002)
#define REG_VRAMMOD	((u16*)0x3c0004)
#define REG_LSPCMODE	((u16*)0x3c0006)
#define REG_TIMERHIGH	((u16*)0x3c0008)
#define REG_TIMERLOW	((u16*)0x3c000a)
#define REG_IRQACK	((u8*)0x3c000c)
#define REG_TIMERSTOP	((u8*)0x3c000e)

/* System registers */
#define REG_NOSHADOW	((u8*)0x3a0001)
#define REG_SHADOW	((u8*)0x3a0011)
#define REG_SWPBIOS	((u8*)0x3a0003)
#define REG_SWPROM	((u8*)0x3a0013)
#define REG_CRDUNLOCK1	((u8*)0x3a0005)
#define REG_CRDLOCK1	((u8*)0x3a0015)
#define REG_CRDLOCK2	((u8*)0x3a0007)
#define REG_CRDUNLOCK2	((u8*)0x3a0017)
#define REG_CRDREGSEL	((u8*)0x3a0009)
#define REG_CRDNORMAL	((u8*)0x3a0019)
#define REG_BRDFIX	((u8*)0x3a000b)
#define REG_CRTFIX	((u8*)0x3a001b)
#define REG_SRAMLOCK	((u8*)0x3a000d)
#define REG_SRAMUNLOCK	((u8*)0x3a001d)
#define REG_PALBANK1	((u8*)0x3a000f)
#define REG_PALBANK0	((u8*)0x3a001f)

/* IO registers */
#define REG_P1CNT	((u8*)0x300000)
#define REG_DIPSW	((u8*)0x300001)
#define REG_WATCHDOGW	((u8*)0x300001)
#define REG_SYSTYPE	((u8*)0x300081)
#define REG_SOUND	((u8*)0x320000)
#define REG_STATUS_A	((u8*)0x320001)
#define REG_P2CNT	((u8*)0x340000)
#define REG_STATUS_B	((u8*)0x380000)
#define REG_POUTPUT	((u8*)0x380001)
#define REG_CRDBANK	((u8*)0x380011)
#define REG_SLOT	((u8*)0x380021)
#define REG_LEDLATCHES	((u8*)0x380031)
#define REG_LEDDATA	((u8*)0x380041)
#define REG_RTCCTRL	((u8*)0x380051)
#define REG_RESETCC1	((u8*)0x380061)
#define REG_RESETCC2	((u8*)0x380063)
#define REG_RESETCL1	((u8*)0x380065)
#define REG_RESETCL2	((u8*)0x380067)
#define REG_SETCC1	((u8*)0x3800e1)
#define REG_SETCC2	((u8*)0x3800e3)
#define REG_SETCL1	((u8*)0x3800e5)
#define REG_SETCL2	((u8*)0x3800e7)

/* Memory mapped palette RAM */
#define MMAP_PALBANK1	((u16*)0x400000)


#endif /* __NGDEVKIT_REGISTERS_H__ */
