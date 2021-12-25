/*
 * Backup RAM management on MVS
 * Copyright (c) 2021 Damien Ciabrini
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


#endif /* __NGDEVKIT_BACKUP_RAM_H__ */
