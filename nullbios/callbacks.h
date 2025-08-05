/*
 * BIOS macros for game callback functions
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

#ifndef __NULLBIOS_CALLBACKS_H__
#define __NULLBIOS_CALLBACKS_H__

#define rom_callback_player_start ((void (*)(void))0x128)

#define rom_callback_demo_end ((void (*)(void))0x12e)

#define rom_callback_coin_sound ((void (*)(void))0x134)

#endif /* __NULLBIOS_CALLBACKS_H__ */
