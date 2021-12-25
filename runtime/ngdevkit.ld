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
  ROM (rx)     : ORIGIN = 0x000000, LENGTH = 512K
  RAM (rw)     : ORIGIN = 0x100000, LENGTH = 0xf300
  BIOSRAM (rw) : ORIGIN = 0x10fcee, LENGTH = 0x312
}

SECTIONS {
  .bss.bram ORIGIN(RAM) : SUBALIGN(0) {
    *(.bss.bram)
  } >RAM =0xffffffff

  .text : {
    /* The link script depends on various user configured flags,
     * and provides defaults for unspecified flags. */

    /* ROM NGH ID */
    rom_NGH_ID = DEFINED(rom_NGH_ID)? rom_NGH_ID : 1337;

    /* Eye-catcher: 0: done by BIOS, 1: done by game, 2: none */
    rom_eye_catcher_mode = DEFINED(rom_eye_catcher_mode)? rom_eye_catcher_mode : 0;

    /* Set cartridge-specific IRQ handlers.
     * Fallback to default ones if unspecified by user at link time
     */
    rom_handler_VBlank = DEFINED(rom_handler_VBlank)? rom_handler_VBlank : rom_handler_VBlank_default ;
    rom_handler_Timer = DEFINED(rom_handler_Timer)? rom_handler_Timer : rom_handler_Timer_default ;

    /* Default IRQ handlers call C callback if they exist at link time */
    rom_callback_VBlank = DEFINED( rom_callback_VBlank)? rom_callback_VBlank : 0;
    rom_callback_Timer = DEFINED( rom_callback_Timer)? rom_callback_Timer : 0;

    /* USER commands: use cartridge overrides or the defaults from crt0 */
    rom_mvs_startup_init = DEFINED(rom_mvs_startup_init)? rom_mvs_startup_init : rom_mvs_startup_init_default;
    rom_eye_catcher = DEFINED(rom_eye_catcher)? rom_eye_catcher : rom_eye_catcher_default;
    rom_game = DEFINED(rom_game)? rom_game : rom_game_default;
    rom_title = DEFINED(rom_title)? rom_title : rom_title_default;

    /* C callback functions for USER commands */
    main_mvs_title = DEFINED(main_mvs_title)? main_mvs_title : main;
    coin_sound = DEFINED(coin_sound)? coin_sound : 0;
    player_start = DEFINED(player_start)? player_start : 0;

    /* The actual link of the text segment starts here */
    rom_mem_backup = DEFINED(rom_mem_backup)? rom_mem_backup : ORIGIN(RAM);
    rom_mem_backup_size = DEFINED(rom_mem_backup_size)? rom_mem_backup_size : SIZEOF(.bss.bram);

    /* Make sure crt0 is linked first */
    *ngdevkit-crt0.o(.text)

    /* ROM software DIP switches */
    *(.text.softdip)

    /* remaining code */
    *(.text)
    *(.text.*)

    /* C++ specific sections */
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
  __data_start_in_ram = DEFINED(__data_start_in_ram)? __data_start_in_ram : ( rom_mem_backup + rom_mem_backup_size );
  .data : AT(__data_start) {
    *(.data)
    *(.data.*)
    . = ALIGN(4);  
  } >RAM =0xffffffff
  __data_end = __data_start + SIZEOF(.data);

  .bss.bios ORIGIN(BIOSRAM) : SUBALIGN(0) {
    *bios-ram.o(.bss)
  } >BIOSRAM =0xffffffff

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
