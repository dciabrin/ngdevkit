/*
 * Copyright (c) 2026 Ismaïl Dogru
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

#ifndef __NGDEVKIT_NG_INPUT_H__
#define __NGDEVKIT_NG_INPUT_H__

#include <ngdevkit/bios-ram.h>
#include <ngdevkit/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/// True while any bit in mask is currently held on player 1
static inline u8 ng_p1_held(u8 mask)
{
    return (bios_p1current & mask) != 0;
}

/// True on the single frame any bit in mask transitions released -> held
static inline u8 ng_p1_pressed(u8 mask)
{
    return (bios_p1current & ~bios_p1previous & mask) != 0;
}

/// True on the single frame any bit in mask transitions held -> released
static inline u8 ng_p1_released(u8 mask)
{
    return (bios_p1previous & ~bios_p1current & mask) != 0;
}

#ifdef __cplusplus
}
#endif

#endif /* __NGDEVKIT_NG_INPUT_H__ */
