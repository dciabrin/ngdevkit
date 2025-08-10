/*
 * BIOS system calls
 * Copyright (c) 2020-2025 Damien Ciabrini
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

#ifndef __NGDEVKIT_BIOS_CALLS_H__
#define __NGDEVKIT_BIOS_CALLS_H__

/* These are low-level bios call, not meant to be called directly */
void bios_system_int1(void);
void bios_system_int2(void);
void bios_system_return(void);
void bios_system_io(void);

/* These are MVS-specific bios call, not meant to be called directly */
void bios_credit_check(void);
void bios_credit_down(void);
void bios_read_calendar(void);
void bios_setup_calendar(void);

/**
 * Clear the fix tileset layer
 * The layer is configured to display transparent tiles.
 * The left and right columns display an opaque tile (black).
 *
 * This call does not preserve VRAM memory-mapped registers.
 */
void bios_fix_clear(void);

/**
 * Clear all the sprites
 * Reset the all sprites control blocks to default values:
 *   - sprite height is set to 0 tiles (invisible)
 *   - sprite (x,y) position set (0,380) from top right corner of the screen
 *   - sprite scaling is reset to max value (no scaling)
 * Additionally, make the 1st sprite transparent.
 *
 * This call does not preserve VRAM memory-mapped registers.
 */
void bios_lsp_1st(void);

void bios_mess_out(void);

void bios_card(void);

void bios_card_error(void);

void bios_how_to_play(void);

void bios_checksum(void);

void bios_controller_setup(void);

void bios_cd_data_ready(void);

void bios_cd_data_transfer(void);


#include <ngdevkit/asm/bios-calls.h>

#endif /* __NGDEVKIT_BIOS_CALLS_H__ */
