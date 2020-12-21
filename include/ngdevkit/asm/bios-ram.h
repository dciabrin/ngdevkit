/*
 * BIOS state variables in memory
 * Copyright (c) 2020 Damien Ciabrini
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

#ifndef __NGDEVKIT_ASM_BIOS_RAM_H__
#define __NGDEVKIT_ASM_BIOS_RAM_H__

#define BIOS_Z80ROM_CHECK 0x10fcee
#define BIOS_SLOT_CHECK   0x10fcef

#define BIOS_SYSTEM_MODE   0x10fd80
#define BIOS_SYSRET_STATUS 0x10fd81

#define BIOS_MVS_FLAG     0x10fd82
#define BIOS_COUNTRY_CODE 0x10fd83

#define BIOS_GAME_DIP 0x10fd84

#define BIOS_P1STATUS   0x10fd94
#define BIOS_P1PREVIOUS 0x10fd95
#define BIOS_P1CURRENT  0x10fd96
#define BIOS_P1CHANGE   0x10fd97
#define BIOS_P1REPEAT   0x10fd98
#define BIOS_P1TIMER    0x10fd99
#define BIOS_P2STATUS   0x10fd9a
#define BIOS_P2PREVIOUS 0x10fd9b
#define BIOS_P2CURRENT  0x10fd9c
#define BIOS_P2CHANGE   0x10fd9d
#define BIOS_P2REPEAT   0x10fd9e
#define BIOS_P2TIMER    0x10fd9f
#define BIOS_P3STATUS   0x10fda0
#define BIOS_P3PREVIOUS 0x10fda1
#define BIOS_P3CURRENT  0x10fda2
#define BIOS_P3CHANGE   0x10fda3
#define BIOS_P3REPEAT   0x10fda4
#define BIOS_P3TIMER    0x10fda5
#define BIOS_P4STATUS   0x10fda6
#define BIOS_P4PREVIOUS 0x10fda7
#define BIOS_P4CURRENT  0x10fda8
#define BIOS_P4CHANGE   0x10fda9
#define BIOS_P4REPEAT   0x10fdaa
#define BIOS_P4TIMER    0x10fdab
#define BIOS_STATCURNT  0x10fdac
#define BIOS_STATCHANGE 0x10fdad

#define BIOS_USER_REQUEST 0x10fdae
#define BIOS_USER_MODE    0x10fdaf
#define BIOS_CREDIT_DEC1  0x10fdb0
#define BIOS_CREDIT_DEC2  0x10fdb1
#define BIOS_CREDIT_DEC3  0x10fdb2
#define BIOS_CREDIT_DEC4  0x10fdb3
#define BIOS_START_FLAG   0x10fdb4
#define BIOS_PLAYER_MOD1  0x10fdb6
#define BIOS_PLAYER_MOD2  0x10fdb7
#define BIOS_PLAYER_MOD3  0x10fdb8
#define BIOS_PLAYER_MOD4  0x10fdb9

#define BIOS_MESS_POINT 0x10fdbe
#define BIOS_MESS_BUSY  0x10fdc2

#define BIOS_CARD_COMMAND 0x10fdc4
#define BIOS_CARD_MODE    0x10fdc5
#define BIOS_CARD_ANSWER  0x10fdc6
#define BIOS_CARD_START   0x10fdc8
#define BIOS_CARD_SIZE    0x10fdcc
#define BIOS_CARD_FCB     0x10fdce
#define BIOS_CARD_SUB     0x10fdd0

#define BIOS_YEAR    0x10fdd2
#define BIOS_MONTH   0x10fdd3
#define BIOS_DAY     0x10fdd4
#define BIOS_WEEKDAY 0x10fdd5
#define BIOS_HOUR    0x10fdd6
#define BIOS_MINUTE  0x10fdd7
#define BIOS_SECOND  0x10fdd8

#define BIOS_COMPULSION_TIMER       0x10fdda
#define BIOS_COMPULSION_FRAME_TIMER 0x10fddb

#define BIOS_DEVMODE            0x10fe80
#define BIOS_FRAME_COUNTER      0x10fe88
#define BIOS_BRAM_USED          0x10febf
#define BIOS_TITLE_MODE         0x10fec5
#define BIOS_STATCURNT_RAW      0x10fedc
#define BIOS_STATCHANGE_RAW     0x10fedd
#define BIOS_FRAME_SKIP         0x10fee1
#define BIOS_INT1_SKIP          0x10fee3
#define BIOS_INT1_FRAME_COUNTER 0x10fee4

#define BIOS_4P_REQUESTED 0x10fef8
#define BIOS_4P_MODE      0x10fefa
#define BIOS_4P_PLUGGED   0x10fefb

#endif /* __NGDEVKIT_ASM_BIOS_RAM_H__ */
