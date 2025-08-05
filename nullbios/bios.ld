/*
 * linkscript for nullbios, an open source BIOS for Neo Geo.
 * Copyright (c) 2015 Damien Ciabrini
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

MEMORY {
  BIOSROM (rx) : ORIGIN = 0xc00000, LENGTH = 128K
  /* The end of the RAM is reserved for BIOS usage (786 bytes) */
  BIOSRAM (rw) : ORIGIN = 0x10fcee, LENGTH = 0x312
  /* Backup RAM address space, on MVS only */
  BIOSBRAM (rw) : ORIGIN = 0xd00000, LENGTH = 6816
}

SECTIONS {
  .text : {
    *(.text)
    *(.text.*)
    . = ALIGN(4);
  } >BIOSROM =0xffffffff

  .rodata (READONLY) : {
    *(.roda)
    *(.rodata)
    *(.rodata.*)
    . = ALIGN(4);
  } >BIOSROM =0xffffffff

  .bss.bios : SUBALIGN(0) {
    *bios-ram.o(.bss)
  } >BIOSRAM

  .bss.bram : SUBALIGN(0) {
    *bios-backup-ram.o(.bss)
  } >BIOSBRAM

  .padding (READONLY) : {
    . = ALIGN(0xc1ffff);
    BYTE(0xff);
  } >BIOSROM =0xffffffff

  /DISCARD/ : { *(.comment) }

}
