/*
 * BIOS state variables in backup memory
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

#ifndef __NGDEVKIT_BIOS_BACKUP_RAM_H__
#define __NGDEVKIT_BIOS_BACKUP_RAM_H__

#include <ngdevkit/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* initialization marker for the backup RAM */
extern char bram_ok_check[16];

/* coin check */
extern u8 bram_coin_deposit_previous;
extern u8 bram_coin_deposit_current;
extern u8 bram_coin_deposit_rising;
extern u8 bram_coin_deposit_rising2;

/* coin tracking */
extern u8 bram_p1_coins;
extern u8 bram_p2_coins;

/* credit tracking */
extern u8 bram_p1_credits_bcd;
extern u8 bram_p2_credits_bcd;

/* cabinet settings */
extern u8 bram_settings_coins_for_p1_credit;
extern u8 bram_settings_credits_for_p1;
extern u8 bram_settings_coins_for_p2_credit;
extern u8 bram_settings_credits_for_p2;
extern u8 bram_settings_coins_for_p3_credit;
extern u8 bram_settings_credits_for_p3;
extern u8 bram_settings_coins_for_p4_credit;
extern u8 bram_settings_credits_for_p4;
extern u8 bram_settings_game_select;
extern u8 bram_settings_game_start_compulsion;
extern u8 bram_settings_compulsion_secs_bcd;
extern u8 bram_settings_compulsion_frames_bcd;
extern u8 bram_settings_demo_sound;
extern u8 bram_settings_detected_slots;

/* cabinet status */
extern u32 bram_play_time;
extern u8 bram_play_time_frame_timer;

extern u8 bram_1st_bios_attract_slot;

#ifdef __cplusplus
}
#endif

/*
 * RAM addresses for all the variables declared above
 */
#include <ngdevkit/asm/bios-backup-ram.h>

#endif /* __NGDEVKIT_BIOS_BACKUP_RAM_H__ */
