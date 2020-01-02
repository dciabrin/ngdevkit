/*
 * linkscript for Neo Geo
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

/* add crt0 here to ensure it is always included and come first,
 * even when gcc is called with -nostartfiles
 */
STARTUP(ngdevkit-crt0.o)

/* Add implementation of syscalls as expected by newlib */
GROUP(-lsyscalls)

MEMORY {
  ROM (rx) : ORIGIN = 0x000000, LENGTH = 512K
  RAM (rw) : ORIGIN = 0x100000, LENGTH = 0xf300
}

SECTIONS {
  .text : {
    *(.text)
    *(.text.*)

    /* Set cartridge-specific information (NGH, name, DIP switches...)
     * Fallback to default values if unspecified by user at link time
     */
    rom_NGH_ID = DEFINED(rom_NGH_ID)? rom_NGH_ID : 1337;
    rom_info_JP = DEFINED(rom_info_JP)? rom_info_JP : rom_info_default;
    rom_info_US = DEFINED(rom_info_US)? rom_info_US : rom_info_default;
    rom_info_EU = DEFINED(rom_info_EU)? rom_info_EU : rom_info_default;

    /* Eye-catcher: 0: done by BIOS, 1: done by game, 2: none
     */
    rom_eye_catcher = DEFINED(rom_eye_catcher)? rom_eye_catcher : 0;

    /* Set cartridge-specific IRQ handlers.
     * Fallback to default ones if unspecified by user at link time
     */
    rom_handler_VBlank = DEFINED(rom_handler_VBlank)? rom_handler_VBlank : rom_handler_VBlank_default ;
    rom_handler_Timer = DEFINED(rom_handler_Timer)? rom_handler_Timer : rom_handler_Timer_default ;

    /* Default IRQ handlers call C callback if they exist at link time */
    rom_callback_VBlank = DEFINED( rom_callback_VBlank)? rom_callback_VBlank : 0;
    rom_callback_Timer = DEFINED( rom_callback_Timer)? rom_callback_Timer : 0;

    *(.ctors)
    *(.dtors)
    *(.eh_frame)
    *(.jcr)

    . = ALIGN(4);  
  } >ROM =0xffffffff

  .init :
  {
    KEEP(*(.init))
  } >ROM =0xffffffff
  .fini :
  {
    KEEP(*(.fini))
  } >ROM =0xffffffff
  __text_end = ADDR(.text) + SIZEOF(.text) + SIZEOF(.init) + SIZEOF(.fini) ;

  __rodata_start = __text_end ;
  .rodata : {
    *(.roda)
    *(.rodata)
    *(.rodata.*)
    . = ALIGN(4);  
  } >ROM =0xffffffff
  __rodata_end = __rodata_start + SIZEOF(.rodata);

  __data_start = __rodata_end ;
  .data : AT(__data_start) {
    *(.data)
    *(.data.*)
    . = ALIGN(4);  
  } >RAM =0xffffffff
  __data_end = __data_start + SIZEOF(.data);

  __bss_start = __data_end ;
  .bss : AT(__data_end) {
    *(.bss)
    *(.bss.*)
    . = ALIGN(4);
  } >RAM =0xffffffff
  __bss_end = __bss_start + SIZEOF(.bss);

  /* Start of heap. Used by libsyscalls in sbrk() */
  _end = . ;

   /* Generate a full size, 128K ROM */
  .padding __bss_end : {
    . = ALIGN(0x7ffff);
    BYTE(0xff);
  } >ROM =0xffffffff
}
