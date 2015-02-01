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
  ROM (rx) : ORIGIN = 0xc00000, LENGTH = 128K
  RAM (rw) : ORIGIN = 0x10f300, LENGTH = 3328
}

SECTIONS {
  .text : {
    *(.text)
    *(.text.*)
    . = ALIGN(4);
  } >ROM =0xffffffff
  .rodata : {
    *(.roda)
    *(.rodata)
    *(.rodata.*)
    . = ALIGN(4);
  } >ROM =0xffffffff
  .data : {
    *(.data)
    *(.data.*)
    . = ALIGN(4);
  } >RAM =0xffffffff
  .padding : {
    . = ALIGN(0xc1ffff);
    BYTE(0xff);
  } >ROM =0xffffffff
}
