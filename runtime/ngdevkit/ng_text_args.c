/*
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


/// Handy function to display a string on the fix map
void ng_text_args(u8 x, u8 y, u8 palette, u16 start_tile, const char *text) {
    u16 base_val = (palette << 12) | start_tile;
    *REG_VRAMADDR=ADDR_FIXMAP+(x<<5)+y;
    *REG_VRAMMOD=32;
    while (*text) *REG_VRAMRW = (u16)(base_val+*text++);
}
