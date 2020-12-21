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

#ifndef __NGDEVKIT_BIOS_RAM_H__
#define __NGDEVKIT_BIOS_RAM_H__

// BIOS checks
extern u8 bios_z80rom_check;
extern u8 bios_slot_check;

// System
extern u8 bios_system_mode;
extern u8 bios_sysret_status;

// Running hardware
extern u8 bios_mvs_flag;
extern u8 bios_country_code;

// Game DIP switches
extern u8 bios_game_dip[16];

// Joypad
#define CNT_UP      (1<<0)
#define CNT_DOWN    (1<<1)
#define CNT_LEFT    (1<<2)
#define CNT_RIGHT   (1<<3)
#define CNT_A       (1<<4)
#define CNT_B       (1<<5)
#define CNT_C       (1<<6)
#define CNT_D       (1<<7)
#define CNT_START1  (1<<0)
#define CNT_SELECT1 (1<<1)
#define CNT_START2  (1<<2)
#define CNT_SELECT2 (1<<3)
extern u8 bios_p1status;
extern u8 bios_p1previous;
extern u8 bios_p1current;
extern u8 bios_p1change;
extern u8 bios_p1repeat;
extern u8 bios_p1timer;
extern u8 bios_p2status;
extern u8 bios_p2previous;
extern u8 bios_p2current;
extern u8 bios_p2change;
extern u8 bios_p2repeat;
extern u8 bios_p2timer;
extern u8 bios_p3status;
extern u8 bios_p3previous;
extern u8 bios_p3current;
extern u8 bios_p3change;
extern u8 bios_p3repeat;
extern u8 bios_p3timer;
extern u8 bios_p4status;
extern u8 bios_p4previous;
extern u8 bios_p4current;
extern u8 bios_p4change;
extern u8 bios_p4repeat;
extern u8 bios_p4timer;
extern u8 bios_statcurnt;
extern u8 bios_statchange;

// System-related
extern u8 bios_user_request;
extern u8 bios_user_mode;
extern u8 bios_credit_dec1;
extern u8 bios_credit_dec2;
extern u8 bios_credit_dec3;
extern u8 bios_credit_dec4;
extern u8 bios_start_flag;
extern u8 bios_player_mod1;
extern u8 bios_player_mod2;
extern u8 bios_player_mod3;
extern u8 bios_player_mod4;

// MESS OUT
extern u32 bios_mess_point;
extern u8 bios_mess_busy;

// Memory card
extern u8 bios_card_command;
extern u8 bios_card_mode;
extern u8 bios_card_answer;
extern u32 bios_card_start;
extern u16 bios_card_size;
extern u16 bios_card_fcb;
extern u16 bios_card_sub;

// Calendar
extern u8 bios_year;
extern u8 bios_month;
extern u8 bios_day;
extern u8 bios_weekday;
extern u8 bios_hour;
extern u8 bios_minute;
extern u8 bios_second;

// MVS start timer
extern u8 bios_compulsion_timer;
extern u8 bios_compulsion_frame_timer;

// BIOS internals
extern u8 bios_devmode[8];
extern u32 bios_frame_counter;
extern u8 bios_bram_used;
extern u8 bios_title_mode;
extern u8 bios_statcurnt_raw;
extern u8 bios_statchange_raw;
extern u8 bios_frame_skip;
extern u8 bios_int1_skip;
extern u8 bios_int1_frame_counter;

// 4 players extension
extern u8 bios_4p_requested;
extern u8 bios_4p_mode;
extern u8 bios_4p_plugged;


/*
 * RAM addresses for all the variables declared above
 */
#include <ngdevkit/asm/bios-ram.h>

#endif /* __NGDEVKIT_BIOS_RAM_H__ */
