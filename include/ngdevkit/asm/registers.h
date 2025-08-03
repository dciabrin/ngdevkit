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

#ifndef __NGDEVKIT_ASM_REGISTERS_H__
#define __NGDEVKIT_ASM_REGISTERS_H__

/* Video registers */
#define REG_VRAMADDR	0x3c0000
#define REG_VRAMRW	0x3c0002
#define REG_VRAMMOD	0x3c0004
#define REG_LSPCMODE	0x3c0006
#define REG_TIMERHIGH	0x3c0008
#define REG_TIMERLOW	0x3c000a
#define REG_IRQACK	0x3c000c
#define REG_TIMERSTOP	0x3c000e

/* System registers */
#define REG_NOSHADOW	0x3a0001
#define REG_SHADOW	0x3a0011
#define REG_SWPBIOS	0x3a0003
#define REG_SWPROM	0x3a0013
#define REG_CRDUNLOCK1	0x3a0005
#define REG_CRDLOCK1	0x3a0015
#define REG_CRDLOCK2	0x3a0007
#define REG_CRDUNLOCK2	0x3a0017
#define REG_CRDREGSEL	0x3a0009
#define REG_CRDNORMAL	0x3a0019
#define REG_BRDFIX	0x3a000b
#define REG_CRTFIX	0x3a001b
#define REG_SRAMLOCK	0x3a000d
#define REG_SRAMUNLOCK	0x3a001d
#define REG_PALBANK1	0x3a000f
#define REG_PALBANK0	0x3a001f

/* IO registers */
#define REG_P1CNT	0x300000
#define REG_DIPSW	0x300001
#define REG_WATCHDOGW	0x300001
#define REG_SYSTYPE	0x300081
#define REG_SOUND	0x320000
#define REG_STATUS_A	0x320001
#define REG_P2CNT	0x340000
#define REG_STATUS_B	0x380000
#define REG_POUTPUT	0x380001
#define REG_CRDBANK	0x380011
#define REG_SLOT	0x380021
#define REG_LEDLATCHES	0x380031
#define REG_LEDDATA	0x380041
#define REG_RTCCTRL	0x380051

/* Coin registers */
#define REG_RESETCC1	0x380061
#define REG_RESETCC2	0x380063
#define REG_RESETCL1	0x380065
#define REG_RESETCL2	0x380067
#define REG_SETCC1	0x3800e1
#define REG_SETCC2	0x3800e3
#define REG_SETCL1	0x3800e5
#define REG_SETCL2	0x3800e7

#endif /* __NGDEVKIT_ASM_REGISTERS_H__ */
