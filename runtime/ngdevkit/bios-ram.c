/*
 * System state and configuration in RAM, managed by the BIOS
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

#include <ngdevkit/neogeo.h>

// BIOS checks
u8 bios_z80_rom_check = 0;          /// 0x10fcee
u8 bios_slot_check = 0;             /// 0x10fcef
u8 _bios_unknown01[144] = {};       /// 144 bytes

// System
u8 bios_system_mode = 0;            /// 0x10fd80
u8 bios_sysret_status = 0;          /// 0x10fd81

// Running hardware
u8 bios_mvs_flag = 0;               /// 0x10fd82
u8 bios_country_code = 0;           /// 0x10fd83

// Game DIP switches
u8 bios_game_dip[16] = {};          /// 0x10fd84

// Joypad
u8 bios_p1status = 0;               /// 0x10fd94
u8 bios_p1previous = 0;             /// 0x10fd95
u8 bios_p1current = 0;              /// 0x10fd96
u8 bios_p1change = 0;               /// 0x10fd97
u8 bios_p1repeat = 0;               /// 0x10fd98
u8 bios_p1timer = 0;                /// 0x10fd99
u8 bios_p2status = 0;               /// 0x10fd9a
u8 bios_p2previous = 0;             /// 0x10fd9b
u8 bios_p2current = 0;              /// 0x10fd9c
u8 bios_p2change = 0;               /// 0x10fd9d
u8 bios_p2repeat = 0;               /// 0x10fd9e
u8 bios_p2timer = 0;                /// 0x10fd9f
u8 bios_p3status = 0;               /// 0x10fda0
u8 bios_p3previous = 0;             /// 0x10fda1
u8 bios_p3current = 0;              /// 0x10fda2
u8 bios_p3change = 0;               /// 0x10fda3
u8 bios_p3repeat = 0;               /// 0x10fda4
u8 bios_p3timer = 0;                /// 0x10fda5
u8 bios_p4status = 0;               /// 0x10fda6
u8 bios_p4previous = 0;             /// 0x10fda7
u8 bios_p4current = 0;              /// 0x10fda8
u8 bios_p4change = 0;               /// 0x10fda9
u8 bios_p4repeat = 0;               /// 0x10fdaa
u8 bios_p4timer = 0;                /// 0x10fdab
u8 bios_statcurnt = 0;              /// 0x10fdac
u8 bios_statchange = 0;             /// 0x10fdad

// System Related
u8 bios_user_request = 0;           /// 0x10fdae
u8 bios_user_mode = 0;              /// 0x10fdaf
u8 bios_credit_dec1 = 0;            /// 0x10fdb0
u8 bios_credit_dec2 = 0;            /// 0x10fdb1
u8 bios_credit_dec3 = 0;            /// 0x10fdb2
u8 bios_credit_dec4 = 0;            /// 0x10fdb3
u8 bios_start_flag = 0;             /// 0x10fdb4
u8 _bios_unknown02 = 0;             /// 1 byte
u8 bios_player_mod1 = 0;            /// 0x10fdb6
u8 bios_player_mod2 = 0;            /// 0x10fdb7
u8 bios_player_mod3 = 0;            /// 0x10fdb8
u8 bios_player_mod4 = 0;            /// 0x10fdb9
u8 _bios_unknown03[4] = {};         /// 4 bytes

// MESS OUT Related
u32 bios_mess_point = 0;            /// 0x10fdbe
u8  bios_mess_busy = 0;             /// 0x10fdc2
u8  _bios_unknown04 = 0;            /// 1 byte

// Memory Card Related
u8  bios_card_command = 0;          /// 0x10fdc4
u8  bios_card_mode = 0;             /// 0x10fdc5
u8  bios_card_answer = 0;           /// 0x10fdc6
u8  _bios_unknown05 = 0;            /// 1 byte
u32 bios_card_start = 0;            /// 0x10fdc8
u16 bios_card_size = 0;             /// 0x10fdcc
u16 bios_card_fcb = 0;              /// 0x10fdce
u16 bios_card_sub = 0;              /// 0x10fdd0

// Calendar Related
u8 bios_year = 0;                   /// 0x10fdd2
u8 bios_month = 0;                  /// 0x10fdd3
u8 bios_day = 0;                    /// 0x10fdd4
u8 bios_weekday = 0;                /// 0x10fdd5
u8 bios_hour = 0;                   /// 0x10fdd6
u8 bios_minute = 0;                 /// 0x10fdd7
u8 bios_second = 0;                 /// 0x10fdd8
u8 _bios_unknown06 = 0;             /// 1 byte

// MVS Start Timer
u8 bios_compulsion_timer = 0;       /// 0x10fdda
u8 bios_compulsion_frame_timer = 0; /// 0x10fddb
u8 _bios_unknown07[164] = {};       /// 164 bytes

// BIOS internals
u8  bios_devmode[8] = {};           /// 0x10fe80
u32 bios_frame_counter = 0;         /// 0x10fe88
u8  _bios_unknown08[51] = {};       /// 50 bytes
u8  bios_bram_used = 0;             /// 0x10febf
u8  _bios_unknown09[5] = {};        /// 5 bytes
u8  bios_title_mode = 0;            /// 0x10fec5
u8  _bios_unknown10[22] = {};       /// 22 bytes
u8  bios_statcurnt_raw = 0;         /// 0x10fedc
u8  bios_statchange_raw = 0;        /// 0x10fedd
u8  _bios_unknown11[3] = {};        /// 3 bytes
u8  bios_frame_skip = 0;            /// 0x10fee1
u8  _bios_unknown12 = 0;            /// 1 byte
u8  bios_int1_skip = 0;             /// 0x10fee3
u8  bios_int1_frame_counter = 0;    /// 0x10fee4
u8  _bios_unknown13[19] = {};       /// 19 bytes

// 4 players extension
u8 bios_4p_requested = 0;           /// 0x10fef8
u8 _bios_unknown14 = 0;             /// 1 byte
u8 bios_4p_mode = 0;                /// 0x10fefa
u8 bios_4p_plugged = 0;             /// 0x10fefb
