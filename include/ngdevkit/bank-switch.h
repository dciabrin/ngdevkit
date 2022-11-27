/*
 * Bank switching macros
 * Copyright (c) 2022 Damien Ciabrini
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

#ifndef __NGDEVKIT_BANK_SWITCH_H__
#define __NGDEVKIT_BANK_SWITCH_H__

/* Additional resources for bankswitching
 * https://wiki.neogeodev.org/index.php?title=Bankswitching
 */

/** On hardware, bank switching is managed by the cartridge itself
 * by writing a byte into the P-ROM2 memory address space
 * 0x200000..0x2fffff. This macro arbitrarily uses 0x2ffff0 to work
 * on both MAME and GnGeo.
 */
#define __BANK_SELECT_ADDRESS ((volatile u8*)0x2ffff0)

/** For cartridges with two P-ROMs, select the n-th bank
 * (chunk of 1MB) from the second P-ROM to map into the P-ROM2
 * memory address space (0x200000..0x2FFFFF)
 */
#define P_ROM_SWITCH_BANK(n) *__BANK_SELECT_ADDRESS = (n)

#endif /* __NGDEVKIT_BANK_SWITCH_H__ */
