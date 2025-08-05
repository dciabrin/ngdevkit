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


#define START_SELECT_MASK 0xf
#define ONLY_START_MASK 0x55


void controllers_update_status() {
    // player 1 input
    bios_p1previous = bios_p1current;
    bios_p1current = ~*REG_P1CNT;
    bios_p1change = bios_p1current & (bios_p1current ^ bios_p1previous);

    // player 2 input
    bios_p2previous = bios_p2current;
    bios_p2current = ~*REG_P2CNT;
    bios_p2change = bios_p2current & (bios_p2current ^ bios_p2previous);

    // select/start status
    u8 prevstart = bios_statcurnt_raw;
    bios_statcurnt_raw = (~*REG_STATUS_B) & START_SELECT_MASK;
    bios_statchange_raw = bios_statcurnt_raw & (bios_statcurnt_raw ^ prevstart);
    // start status without select buttons
    bios_statcurnt = bios_statcurnt_raw & ONLY_START_MASK;
    bios_statchange = bios_statcurnt_raw & ONLY_START_MASK;
}
