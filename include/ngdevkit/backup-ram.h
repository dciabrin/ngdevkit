/*
 * Backup RAM management on MVS
 * Copyright (c) 2021-2023 Damien Ciabrini
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

#ifndef __NGDEVKIT_BACKUP_RAM_H__
#define __NGDEVKIT_BACKUP_RAM_H__

/** Attribute for variables that need to get saved into backup RAM
 * The data is automatically saved each time the attract mode is run,
 * and restored when the ROM is being started.
 *
 * Example:
 *   u8 _backup_ram high_score;
 *
 * Note: backup only takes place on MVS hardware
 */
#define _backup_ram __attribute__((section(".bss.bram")))

/** Macro to override the start of the backup address space in memory.
 * If used, the address specified must be past the .data and .bss segments.
 * This macro must be used at the top-level scope only.
 *
 * Example:
 *   ROM_BACKUP_DATA_ADDRESS(0x102000);
 *
 * Note: backup only takes place on MVS hardware
 */
#define ROM_BACKUP_DATA_ADDRESS(addr) \
    __asm__(".global rom_backup_data_address\n.equ rom_backup_data_address," #addr)

/** Macro to override the size of the backup address space in memory.
 * This macro can be used to reserve up to 4KiB of RAM that gets
 * automatically saved each time the attract mode is run, and restored
 * when the ROM is being started.
 * This macro must be used at the top-level scope only.
 *
 * Example:
 *   ROM_BACKUP_DATA_SIZE(0x1000);
 *
 * Note: backup only takes place on MVS hardware
 */
#define ROM_BACKUP_DATA_SIZE(size) \
    __asm__(".global rom_backup_data_size\n.equ rom_backup_data_size," #size); \
    _Static_assert(size<=4096, "backup data size cannot exceed 4096 bytes")

#endif /* __NGDEVKIT_BACKUP_RAM_H__ */
