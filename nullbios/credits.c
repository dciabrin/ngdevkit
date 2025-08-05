/*
 * controllers management for BIOS
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

#include <ngdevkit/bios-backup-ram.h>
#include <ngdevkit/bios-ram.h>
#include <ngdevkit/registers.h>
#include "utils.h"
#include "callbacks.h"

#define FREE_PLAY_MASK 0x40
#define COIN_MASK 3
#define P1_BIT 1
#define P2_BIT 2



void credits_init_counters_and_locks(void) {
    WITH_BACKUP_RAM_RW ({
        // nullbios semantics:
        //   . start up with no credits
        //   . 1UP CC is 1 credit
        //   . 2UP CC is 2 credits
        bram_p1_credits_bcd = 0;
        bram_p2_credits_bcd = 0;
        bram_settings_credits_for_p1 = 1;
        bram_settings_credits_for_p2 = 2;
        bios_credit_dec1 = 1;
        bios_credit_dec2 = 1;
        bram_settings_game_start_compulsion = 0x30;

        // allow credits (i.e. disable credit lock mechanism)
        *REG_RESETCL1 = 0;
        *REG_RESETCL2 = 0;

        // clear state
        bram_coin_deposit_previous = 0;
        bram_coin_deposit_current = 0;
        bios_compulsion_timer_over = 1;
    });
}


void credits_update_status(void) {
    u8 old = bram_coin_deposit_previous;
    WITH_BACKUP_RAM_RW ({
        bram_coin_deposit_previous = bram_coin_deposit_current;
        bram_coin_deposit_current = ~*REG_STATUS_A & COIN_MASK;
    });

    // detect only rising edges
    old = ~( old | bram_coin_deposit_previous);
    u8 transition = bram_coin_deposit_previous ^ bram_coin_deposit_current;
    u8 rising = old & transition;
    bram_coin_deposit_rising = rising;

    if (rising) {
        // when credit is inserted the following actions take place:
        //   . bump credit count
        //   . reset the compulsion start timer
        WITH_BACKUP_RAM_RW ({
            CC_CLEAR_X_FLAG();
            if (rising & P1_BIT) ADD_BCD(bram_p1_credits_bcd, bram_settings_credits_for_p1);
            if (rising & P2_BIT) ADD_BCD(bram_p1_credits_bcd, bram_settings_credits_for_p2);

            if (bios_compulsion_timer_over) {
                rom_callback_demo_end();
                bios_compulsion_timer_over = 0;
            }
        });

        bios_compulsion_frame_timer = 0x3b;
        bios_compulsion_timer = bram_settings_game_start_compulsion;

        // only when the game is not running yet:
        //   . call the game's "coin_sound" callback function
        //   . prepare a restart to game's title (user request 3)
        //   . reset the stack and soft reset to game's title
        if (bios_user_mode != 2) {
            bios_user_request = 3;
            __asm__ ("lea.l   0x10f300, %sp\n"
                     "pea.l   soft_reset\n"
                     "rts");
        }
    }
}


void credits_substract_for_new_players(void) {
    // This stub does not update credits stats in book keeping
    // It also assumes we always substract 1 credit per player
    WITH_BACKUP_RAM_RW ({
        /* { */
        /*     u8 tmp; */
        /*     __asm__ volatile ("sub.b %0, %0" : "=r" (tmp) : : "cc"); */
        /* } */
        CC_CLEAR_X_FLAG();
        if (bios_start_flag & P1_BIT) SUB_BCD(bram_p1_credits_bcd, 1);
        if (bios_start_flag & P2_BIT) SUB_BCD(bram_p1_credits_bcd, 1);
        bios_compulsion_timer_over = 1;
    });
}


void credits_check_game_start() {
    // nothing to check if BIOS is initializing
    if (bios_user_mode == 0) return;
    // nothing to check if there's no credit
    if (bram_p1_credits_bcd == 0) return;

    u8 trigger;
    trigger = (bios_statchange_raw>>1) & 2;
    trigger |= bios_statchange_raw & 1;

    if (bios_user_mode == 1) {
        // cannot run 2 players if there is not enough credit
        if (bram_p1_credits_bcd<2)
            trigger = trigger & P1_BIT;

        // in game mode: p2 start means "player 2 wants to play"
        // but in title mode: p2 start means "2 players requested"
        if (trigger & P2_BIT)
            trigger |= P1_BIT;
    }

    // compulsion timer is off when game is running
    if (!bios_compulsion_timer_over ) {
        if (--bios_compulsion_frame_timer == 0) {
            SUB_BCD(bios_compulsion_timer, 1);
            if (bios_compulsion_timer == 0) {
                trigger |= 1;
            } else {
                bios_compulsion_frame_timer = 0x3b;
            }
        }
    }

    if (trigger != 0) {
        bios_start_flag = trigger;
        rom_callback_player_start();
        if (bios_user_mode == 2) {
            credits_substract_for_new_players();
            bios_compulsion_timer = 0;
            bios_sysret_status = 3;
        }
    }
}


void credits_added() {
    // no sound when attract mode is running (not implemented in nullbios)
    if (bios_frame_skip) return;
    // no sound when switching to next slot (not implemented in nullbios)
    if (bios_sysret_status == 2) return;
    // no sound if the sound driver is not ready
    if (bios_z80_setup_in_progress) return;
    // TODO condition from bios RAM 10fee2
    if (bios_no_coin_sound) {
        *REG_SOUND = 0x7f; // no-op sound
    } else {
        rom_callback_coin_sound();
    }
}


// BIOS public API

// CREDIT_CHECK
// ---
// Check whether credits are available for what is requested by P1 and P2
// (resp bios_credit_dec1 and bios_credit_dec2). if not, clear the requests.
// This call does not decrement available credits. See CREDIT_DOWN.
// Note: when in title mode, of only P2 is requested, consider this is a
// two player game and decrement twice the amount requested for P2
//
void impl_credit_check(void) {
    // nothing to check if hardware is not a MVS
    if (bios_mvs_flag == 0) return;
    // nothing to check if "free play" dip switch is on
    if (*REG_DIPSW & FREE_PLAY_MASK) return;
    // two players requested during title mode
    if ((bios_user_mode == 1) && (bios_credit_dec1 == 0)) {
        bios_credit_dec2 += bios_credit_dec2;
    }

    // TODO: use cc instead of MSB to detect underflow
    u8 available = bram_p1_credits_bcd;
    SUB_BCD(available, bios_credit_dec1);
    if (available & 0x80) bios_credit_dec1 = 0;
    SUB_BCD(available, bios_credit_dec2);
    if (available & 0x80) bios_credit_dec2 = 0;
}

// CREDIT_DOWN
// ---
// Decrement credits for each player that is requesting to start game
// and update game statistics in backup RAM for book keeping.
//
void impl_credit_down(void) {
    credits_substract_for_new_players();
}
