/*
 * Copyright (c) 2024 Damien Ciabrini
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

#include <stdio.h>
#include <stdbool.h>
#include <ngdevkit/soft-dip.h>
#include <ngdevkit/bios-ram.h>


const dip_str12_t* bios_dip_name(u8 region, dip_type_t type, u8 num) {
    const rom_dip_t *dip;
    if (!bios_mvs_flag) return NULL;

    switch(region){
    case BIOS_COUNTRY_JP:
        dip = &dip_jp_rom;
        break;
    case BIOS_COUNTRY_US:
        dip = &dip_us_rom;
        break;
    case BIOS_COUNTRY_EU:
        dip = &dip_eu_rom;
        break;
    default:
        return NULL;
    }

    // find string offset
    u8 current_type = 0;
    const dip_str12_t * str=&dip->strings[0];
    for (u8 i=0; i<2; i++) {
        bool used = DIP_TIME[i].min != 0xff || DIP_TIME[i].sec != 0xff;
        if (type == current_type && i == num)
            return used?str:NULL;
        if (used)
            str++;
    }
    if (type == current_type)
        return NULL;
    current_type++;
    for (u8 i=0; i<2; i++) {
        bool used = DIP_INT[i] != 0xff;
        if (type == current_type && i == num)
            return used?str:NULL;
        if (used)
            str++;
    }
    if (type == current_type)
        return NULL;
    current_type++;
    for (u8 i=0; i<10; i++) {
        bool used = dip->enum_dips[i].length != 0x00;
        if (type == current_type && i == num)
            return used?str:NULL;
        if (used) {
            str++;
            str+=dip->enum_dips[i].length;
        }
    }
    return NULL;
}

const dip_str12_t* bios_dip_enum_choices(u8 region, u8 num) {
    const dip_str12_t *tmp = bios_dip_name(region, DIP_TYPE_ENUM, num);
    if (tmp != NULL) {
        return tmp+1;
    } else {
        return NULL;
    }
}
