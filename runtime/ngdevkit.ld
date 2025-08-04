/*
 * linkscript for Neo Geo
 * Copyright (c) 2015-2025 Damien Ciabrini
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


/* Note: this linkscript can produce an ELF that is suitable for
 * being transformed into a PROM (cartridge) or BIN file (CDROM).
 * both targets require a dedicated crt0, that is passed to the
 * linker via the ngdevkit specfile in use.
 */

/* Add implementation of syscalls as expected by newlib */
GROUP(-lsyscalls)

MEMORY {
  /* Regular program address space for the m68k */
  ROM1 (rx)    : ORIGIN = 0x000000, LENGTH = 1024K
  /* Additional program address space, bank-switched */
  ROM2 (rx)    : ORIGIN = 0x200000, LENGTH = 1024K
  /* BRAM defaults to 0x100000, unless overriden in the cartridge */
  BRAM (rw)    : ORIGIN = rom_backup_data_address, LENGTH = 0x1000
  /* RAM address space for the m68k */
  /* Note: 10f300 is the default supervisor's stack pointer, and
   * stack grows downwards, so do not fill RAM up to 10f300 */
  RAM  (rw)    : ORIGIN = 0x100000, LENGTH = 0xf300
  /* The end of the RAM is reserved for BIOS usage (786 bytes) */
  BIOSRAM (rw) : ORIGIN = 0x10fcee, LENGTH = 0x312
  /* Backup RAM address space, on MVS only */
  BIOSBRAM (rw) : ORIGIN = 0xd00000, LENGTH = 6816
}

SECTIONS {
  /* The first part of the ROM holds all the cartridge's description.
   * This is used by the hardware to boot into the main program.
   */
  .text.boot : {
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

    /* Make sure crt0 is linked first, either one of crt0 or cd-crt0
     * must be used as input file to the linker */
    *ngdevkit-crt0.o(.text)
    *ngdevkit-cd-crt0.o(.text)

    /* ROM software DIP switches */
    *(.text.softdip)
    . = ALIGN(4);
  } >ROM1 =0xffffffff
  __text_boot_end = .;

  /* Allocate the read only data first (e.g. strings, constant
   * global variables). Those are meant to stay in ROM at runtime.
   */
  __rodata_start = __text_boot_end;
  .rodata : AT(__rodata_start) {
    /* The devkit's static libraries are linked first */
    *libgcc.a:*(.roda .rodata .rodata.*)
    *libc.a:*(.roda .rodata .rodata.*)
    *libsyscalls.a:*(.roda .rodata .rodata.*)
    *libngdevkit.a:*(.roda .rodata .rodata.*)

    /* Then all data that are not explicitely meant to be bank-switched */
    EXCLUDE_FILE (*__bank*) *(.roda .rodata .rodata.*)
    . = ALIGN(4);
  } >ROM1 =0xffffffff
  __rodata_end = .;


  /* The following segments deal with symbols that reside
   * in RAM at runtime.
   */

  /* For MVS, when the cartridge uses global variables that
   * are meant to be saved in backup RAM, the C runtime
   * expects them to be at the beginning of the RAM.
   * They get saved and restored by the BIOS automatically.
   *
   * Note: If the user specifies its own backup RAM location,
   * the address must be past all data managed by this link
   * script or the C runtime will not work properly.
   */
  /* Note: use 0x100000 instead of ORIGIN(RAM) because this
   * reference is not resolved properly by the MEMORY command
   */
  rom_backup_data_address = DEFINED(rom_backup_data_address)? rom_backup_data_address : 0x100000;
  .bss.bram rom_backup_data_address : SUBALIGN(0) {
    *(.bss.bram)
    . = ALIGN(4);
  } >BRAM =0xffffffff
  rom_backup_data_size = DEFINED(rom_backup_data_size)? rom_backup_data_size : SIZEOF(.bss.bram);

  /* Next is the .bss segments. It holds all the global variables
   * whose initial value is zero at runtime. The C runtime and
   * the BIOS clear their respective memory ranges at startup.
   */
  .bss.bios ORIGIN(BIOSRAM) : SUBALIGN(0) {
    /* These symbols must be linked prior to the other
     * .bss symbols in the .bss* segments below (or they
     * must be EXCLUDE_FILE'd from the segments below)
     */
    *libngdevkit.a:bios-ram.o(.bss)
  } >BIOSRAM =0xffffffff

  /* The Backup RAM only contains .bss data. This segment is defined
   * to allow C code to reference specific BRAM location as C variables
   */
  .bss.bram : SUBALIGN(0) {
    *libngdevkit.a:bios-backup-ram.o(.bss)
  } >BIOSBRAM

  /* By default, the start of .bss in memory comes right after the
   * backup RAM. If the latter is unused or its address is configured
   * manually, .bss is linked at the beginning of RAM.
   */
  __bss_start = __rodata_end ;
  __bss_start_in_ram = (rom_backup_data_address == ORIGIN(RAM)) ? (rom_backup_data_address + rom_backup_data_size + 3) /4 * 4 : ORIGIN(RAM);
  .bss __bss_start_in_ram : AT(__rodata_end) {
    /* The devkit's static libraries are linked first */
    *libgcc.a:*(.bss .bss.*)
    *libc.a:*(.bss .bss.*)
    *libsyscalls.a:*(.bss .bss.*)
    *libngdevkit.a:*(.bss .bss.*)

    /* Then all data that are not explicitely meant to be bank-switched */
    EXCLUDE_FILE (*__bank*) *(.bss .bss.*)
    . = ALIGN(4);
  } >RAM =0xffffffff
  __bss_end = __bss_start + SIZEOF(.bss);

  /* Next is the .data segment. It holds the initial value
   * of all global variables in C. This range in ROM is
   * copied automatically in RAM at startup by the C runtime.
   *
   * Note: the .bss segment is not stored in the final binary
   * ROM because it only holds zeros. So the .data segment
   * starts right after the .rodata segment.
   */
  __data_start = __rodata_end ;
  __data_start_in_ram = (__bss_start_in_ram + SIZEOF(.bss) + 3) / 4 * 4;
  .data : AT(__data_start) {
    /* The devkit's static libraries are linked first */
    *libgcc.a:*(.data .data.*)
    *libc.a:*(.data .data.*)
    *libsyscalls.a:*(.data .data.*)
    *libngdevkit.a:*(.data .data.*)

    /* Then all data that are not explicitely meant to be bank-switched */
    EXCLUDE_FILE (*__bank*) *(.data .data.*)
    . = ALIGN(4);
  } >RAM =0xffffffff
  __data_end = __data_start + SIZEOF(.data);

  /* For ROMs that use bank-switching, the global variables
   * of the banks are linked at the end of the allocated RAM.
   * These variables are not initialized by the C runtime.
   */
  __data2_start = __data_end ;
  .data2 : AT(__data2_start) {
    /* bank-switched .bss and .data are essentially the same.
     * unitialized, user-managed data only. */
    *(.bss .bss.*)
    *(.data .data.*)
    . = ALIGN(4);
  } >RAM =0xffffffff
  __data2_end = __data2_start + SIZEOF(.data2);

  /* From there, the linker's output location lies at the
   * end of the used RAM. If you're crazy enough to use
   * dynamic allocation like malloc(), this location will
   * be the start of the heap in memory. It is used by
   * sbrk() from libsyscalls.
   * NOTE: If bank-switching is used, `_end` has to be
   * manually allocated to an address that is past all
   * the RAM used by all banks.
   */
  PROVIDE(_end = . );

  /* C++ specific section for global data initialization
   * Note: for ROMs that use bank-switching, global variables
   * from banked files are not initialized.
   */
  __ctors_start = (__data2_end + 3) / 4 * 4;
  .ctors __ctors_start (READONLY) : AT(__ctors_start) {
    /* marker for start of constructor list */
    KEEP (*crtbegin.o(.ctors))
    /* user constructor to be called for global variable init */
    KEEP (*(EXCLUDE_FILE (*crtend.o) .ctors))
    /* user constructor with ordering annotation */
    KEEP (*(SORT(EXCLUDE_FILE (*__bank*) .ctors.*)))
    /* marker for end of constructor list, from crtend.o */
    KEEP (*(.ctors))
  } >ROM1 =0xffffffff
  __ctors_end = __ctors_start + SIZEOF(.ctors);

  /* C++ specific section for global data finalization
   * Note: for ROMs that use bank-switching, global variables
   * from banked files are not finalized.
   */
  __dtors_start = (__ctors_end + 3) / 4 * 4;
  .dtors __dtors_start (READONLY) : AT(__dtors_start) {
    /* marker for start of destructor list */
    KEEP (*crtbegin.o(.dtors))
    /* user destructor to be called for global variable fini */
    KEEP (*(EXCLUDE_FILE (*crtend.o) .dtors))
    /* user destructor with ordering annotation */
    KEEP (*(SORT(EXCLUDE_FILE (*__bank*) .dtors.*)))
    /* marker for end of destructor list */
    KEEP (*(.dtors))
  } >ROM1 =0xffffffff
  __dtors_end = __dtors_start + SIZEOF(.dtors);

  /* global initializations that place before running main()
   * This is used among other things for C++ to run constructors for
   * global variables
   */
  __init_start = __dtors_end;
  .init __init_start : AT(__init_start) {
    /* global _init function prologue */
    KEEP (*ngdevkit-crti.o(.init))
    KEEP (*(SORT_NONE(EXCLUDE_FILE (*ngdevkit-crtn.o) .init)))
    /* global _init function epilogue */
    KEEP (*ngdevkit-crtn.o(.init))
  } >ROM1 =0xffffffff
  __init_end = __init_start + SIZEOF(.init);
  __fini_start = __init_end;
  .fini __fini_start : AT(__fini_start) {
    KEEP (*(SORT_NONE(.fini)))
  } >ROM1 =0xffffffff
  __fini_end = __fini_start + SIZEOF(.fini);

  /* The last part of the ROM contains all the cartridge's code.
   * It is allocated right after the global variables (.data).
   * Note: we first link everything that is not explicitely tagged
   * to end up in the bank-switched P-ROM.
   */
  __text_start = (__fini_end + 3) / 4 * 4;
  .text __text_start : AT(__text_start) {
    /* The devkit's static libraries are linked first */
    *crtstuff.o(.text .text.*)
    *crtbeg.o(.text .text.*)
    *crtend.o(.text .text.*)
    *libgcc.a:*(.text .text.*)
    *libc.a:*(.text .text.*)
    *libsyscalls.a:*(.text .text.*)
    *libngdevkit.a:*(.text .text.*)

    /* Debug: C++ exception header table, used for unwinding stack (untested) */
    *(.eh_frame_hdr)
    *(.eh_frame_entry .eh_frame_entry.*)
    KEEP (*(.eh_frame)) *(.eh_frame.*)

    /* Remaining code */
    EXCLUDE_FILE (*__bank*) *(.text .text.*)

    /* NOTE: If we are explicitly linking a large cartridge, it
     * will span two non-contiguous 1MiB P-ROMs. As soon as an
     * object file cannot fit in ROM1, the linker allocates its
     * entire content into ROM2. It does so for all the remaining
     * object files as well.
     */
  } >ROM1 =0xffffffff

  /* When linking a ROM that uses bank-switching, the segment
   * below holds all the read-only data and the code that will
   * be bank-switched at runtime
   */
  .text2 (READONLY) : {
    /* All the read-only data that are meant to be bank-switched */
    *(.roda .rodata .rodata.*)

    /* Remaining code that overflowed from segment .text, or
     * code that is explicitely meant to be bank-switched */
    *(.text)
    *(.text.*)
  } >ROM2 =0xffffffff
  __text_end = .;

  /* Debug: DWARF debug sections */
  /* primary debug info (functions, types...) */
  .debug_info     0 : { *(.debug_info) }
  /* schema of data in .debug_info */
  .debug_abbrev   0 : { *(.debug_abbrev) }
  /* map addresses to .debug_info data */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_rnglists 0 : { *(.debug_rnglists) }
  /* source code location */
  .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
  /* dwarf 5 segment for source code location */
  .debug_line_str 0 : { *(.debug_line_str) }
  /* source code functions */
  .debug_frame    0 : { *(.debug_frame) }
  /* map values to memory address ranges */
  .debug_loclists 0 : { *(.debug_loclists) }
  /* strings used by dwarf segments */
  .debug_str      0 : { *(.debug_str) }

  /* /\* Debug: C++ exception header table, used for unwinding stack (untested) *\/ */
  /* .eh_frame_hdr   : { *(.eh_frame_hdr) *(.eh_frame_entry .eh_frame_entry.*) } */
  /* .eh_frame       : { KEEP (*(.eh_frame)) *(.eh_frame.*) } */
  /DISCARD/ : { *(.comment) }
}
