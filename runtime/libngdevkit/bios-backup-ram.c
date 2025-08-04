/*
 * System state and configuration in Backup RAM, managed by the BIOS
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

#include <ngdevkit/neogeo.h>

u8 _bram_unused[16] = {};                    /// 0xd00000
char bram_ok_check[16] = {};                 /// 0xd00010
/* coin check */
u8 bram_coin_deposit_previous = 0;           /// 0xd00020
u8 bram_coin_deposit_current = 0;            /// 0xd00021
u8 bram_coin_deposit_rising = 0;             /// 0xd00022
u8 bram_coin_deposit_rising2 = 0;            /// 0xd00023

/* coin tracking */
u8 bram_p1_coins = 0;                        /// 0xd00024
u8 bram_p2_coins = 0;                        /// 0xd00025

u8 _bram_unknown1[14] = {};

/* credit tracking */
u8 bram_p1_credits_bcd = 0;                  /// 0xd00034
u8 bram_p2_credits_bcd = 0;                  /// 0xd00035

u8 _bram_unknown2[4] = {};

/* cabinet settings */
u8 bram_settings_coins_for_p1_credit = 0;    /// 0xd0003a
u8 bram_settings_credits_for_p1 = 0;         /// 0xd0003b
u8 bram_settings_coins_for_p2_credit = 0;    /// 0xd0003c
u8 bram_settings_credits_for_p2 = 0;         /// 0xd0003d
u8 bram_settings_coins_for_p3_credit = 0;    /// 0xd0003e
u8 bram_settings_credits_for_p3 = 0;         /// 0xd0003f
u8 bram_settings_coins_for_p4_credit = 0;    /// 0xd00040
u8 bram_settings_credits_for_p4 = 0;         /// 0xd00041
u8 bram_settings_game_select = 0;            /// 0xd00042
u8 bram_settings_game_start_compulsion = 0;  /// 0xd00043
u8 bram_settings_compulsion_secs_bcd = 0;    /// 0xd00044
u8 bram_settings_compulsion_frames_bcd = 0;  /// 0xd00045
u8 bram_settings_demo_sound = 0;             /// 0xd00046
u8 bram_settings_detected_slots = 0;         /// 0xd00047

/* cabinet status */
u32 bram_play_time = 0;                      /// 0xd00048
u8 bram_play_time_frame_timer = 0;           /// 0xd0004c

u8 _bram_unknown3[11] = {};

u8 bram_1st_bios_attract_slot = 0;           /// 0xd00058

/* cabinet book keeping */
