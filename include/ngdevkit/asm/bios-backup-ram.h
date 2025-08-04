/*
 * BIOS state variables in backup RAM
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

#ifndef __NGDEVKIT_ASM_BIOS_BACKUP_RAM_H__
#define __NGDEVKIT_ASM_BIOS_BACKUP_RAM_H__

#define BRAM_START                          0xd00000

/* initialization marker for the backup RAM */
#define BRAM_OK_CHECK                       0xd00010

/* coin check */
#define BRAM_COIN_DEPOSIT_PREVIOUS          0xd00020
#define BRAM_COIN_DEPOSIT_CURRENT           0xd00021
#define BRAM_COIN_DEPOSIT_RISING            0xd00022
#define BRAM_COIN_DEPOSIT_RISING2           0xd00023

/* coin tracking */
#define BRAM_P1_COINS                       0xd00024
#define BRAM_P2_COINS                       0xd00025

/* credit tracking */
#define BRAM_P1_CREDITS_BCD                 0xd00034
#define BRAM_P2_CREDITS_BCD                 0xd00035

/* Cabinet setting */
#define BRAM_SETTINGS_COINS_FOR_P1_CREDIT   0xd0003a
#define BRAM_SETTINGS_CREDITS_FOR_P1        0xd0003b
#define BRAM_SETTINGS_COINS_FOR_P2_CREDIT   0xd0003c
#define BRAM_SETTINGS_CREDITS_FOR_P2        0xd0003d
#define BRAM_SETTINGS_COINS_FOR_P3_CREDIT   0xd0003e
#define BRAM_SETTINGS_CREDITS_FOR_P3        0xd0003f
#define BRAM_SETTINGS_COINS_FOR_P4_CREDIT   0xd00040
#define BRAM_SETTINGS_CREDITS_FOR_P4        0xd00041
#define BRAM_SETTINGS_GAME_SELECT           0xd00042
#define BRAM_SETTINGS_GAME_START_COMPULSION 0xd00043
#define BRAM_SETTINGS_COMPULSION_SECS_BCD   0xd00044
#define BRAM_SETTINGS_COMPULSION_FRAMES_BCD 0xd00045
#define BRAM_SETTINGS_DEMO_SOUND            0xd00046
#define BRAM_SETTINGS_DETECTED_SLOTS        0xd00047

/* Cabinet status */
#define BRAM_PLAY_TIME                      0xd00048
#define BRAM_PLAY_TIME_FRAME_TIMER          0xd0004c

#define BRAM_1ST_BIOS_ATTRACT_SLOT          0xd00058

#define SLOT1_NGH                           0xd00124
#define SLOT1_SOFT_DIP                      0xd00220
#define SLOT1_BRAM_DATA                     0xd00320


#endif /* __NGDEVKIT_ASM_BIOS_BACKUP_RAM_H__ */
