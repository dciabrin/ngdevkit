/*
 * nullbios - start of BIOS address space
 * Copyright (c) 2015-2020 Damien Ciabrini
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

#include <ngdevkit/asm/registers.h>
#include <ngdevkit/asm/bios-ram.h>
#include <ngdevkit/asm/bios-backup-ram.h>

#define ROM_NGH      0x108
#define ROM_BRAM_PTR 0x10e
#define ROM_BRAM_LEN 0x112
#define DIP_JP_PTR   0x116
#define DIP_US_PTR   0x11a
#define DIP_EU_PTR   0x11e
#define USER         0x122
#define PLAYER_START 0x128
#define DEMO_END     0x12e
#define COIN_SOUND   0x134


        .global soft_reset
/*
 * 68k exception vector table, 256 "vectors", 0x400 bytes
 * After the system boot, this vector table is swapped with the
 * one from the game cartridge (via swapped memory mapping)
 */
   	dc.l	0x10f300		/* Reset: Initial SSP		  */
	dc.l	RESET  	        	/* Reset: Initial PC		  */
	dc.l	RESET                	/* Bus error			  */
	dc.l	RESET	                /* Address error		  */
	dc.l	RESET		        /* Illegal instruction		  */
	dc.l	RESET		        /* Division by zero               */
	dc.l	RESET	                /* CHK instruction		  */
	dc.l	RESET		        /* TRAPV instruction		  */
	dc.l	RESET			/* Privilege violation		  */
	dc.l	RESET			/* Trace			  */
	dc.l	NO_OP			/* Line 1010 - FPU opcode emu     */
	dc.l	NO_OP			/* Line 1111 - FPU opcode emu     */
	.fill	3,   4, 0xffffffff	/* -- unassigned, reserved -- 	  */
	dc.l	NO_OP			/* Uninitialized interrupt vector */
	.fill	8,   4, 0xffffffff	/* -- unassigned, reserved --	  */
	dc.l	NO_OP			/* Spurious interrupt		  */
	dc.l	SYSTEM_INT1     	/* Lvl 1 autovector (VBlank IRQ)  */
	dc.l	SYSTEM_INT2     	/* Lvl 2 autovector (Timer IRQ)   */
 	dc.l	0x00000000		/* Lvl 3 autovector (Cold reset)  */
	.fill	4,   4, 0x00000000	/* Lvl 4..7 autovectors (unused)  */
	.fill	16,  4, 0xffffffff	/* TRAP #n instruction (unused)   */
	.fill	7,   4, 0xffffffff	/* FPU errors (unused)	          */
	dc.l	0xffffffff	        /* -- unassigned, reserved -- 	  */
	.fill	3,   4, 0xffffffff	/* MMU errors (unused)	          */
	.fill	5,   4, 0xffffffff	/* -- unassigned, reserved -- 	  */
	.fill	192, 4, 0xffffffff	/* Device interrupts (unused) 	  */


/*
 * == BIOS descriptor ==
 */
        .org    0x400
        dc.b    BIOS_ROM_HARDWARE       /* AES or MVS */
        dc.b    BIOS_ROM_COUNTRY        /* From EU */

/* The game cartridge's exception vectors point to a jump table
 * in the BIOS, handling boot and common exceptions
 */
GAME_CARTRIDGE_VECTORS:
        .rept   9
	jmp	RESET.l
        .endr

/*
 * BIOS API, exported in a jmp table
 */
        .org    0x438
SYSTEM_INT1:
        jmp     impl_system_int1.l
SYSTEM_INT2:
        jmp     impl_system_int2.l
SYSTEM_RETURN:
        jmp     impl_system_return.l
SYSTEM_IO:
        jmp     impl_system_io.l
CREDIT_CHECK:
        jmp     impl_credit_check.l
CREDIT_DOWN:
        jmp     impl_credit_down.l
READ_CALENDAR:
        jmp     impl_noop
SETUP_CALENDAR:
        jmp     impl_noop
CARD:
        jmp     impl_noop
CARD_ERROR:
        jmp     impl_noop
HOW_TO_PLAY:
        jmp     impl_noop
CHECKSUM:
        jmp     impl_noop
FIX_CLEAR:
        jmp     impl_fix_clear
LST_1st:
        jmp     impl_lst_1st
MESS_OUT:
        jmp     impl_mess_out
CONTROLLER_SETUP:
        jmp     impl_controller_setup
NO_OP:
        jmp     impl_noop


        /* ... only code past this point ... */
        .org    0x4300


/**
 * Initialize the hardware and start user code
 */
RESET:
        /* Supervisor, init IRQ and watchdog timer */
        move    #0x2700, %sr
        move.w  #7, REG_IRQACK
        move.b  %d0, REG_WATCHDOGW

        /* Set initial system information in RAM */
#if BIOS_ROM_HARDWARE != 0
        move.b  #0x80, BIOS_MVS_FLAG
        jsr     load_soft_dip
        jsr     load_game_data_from_bram
        jsr     credits_init_counters_and_locks
#else
        move.b  #0x0, BIOS_MVS_FLAG
#endif
        move.b  #BIOS_ROM_COUNTRY, BIOS_COUNTRY_CODE

        /* Prepare to call USER's request 0 (SystemInit) */
        clr     %d0
        move.b  %d0, BIOS_USER_REQUEST
        move.b  %d0, BIOS_USER_MODE
        jsr     USER.l

        /* Mark init as done, and prepare to jump to game's
         * main function (USER request 2)
         */
        move.b  #2, BIOS_USER_REQUEST

soft_reset:
        /* Supervisor, init IRQ and watchdog timer */
        move    #0x2700, %sr
        move.w  #7, REG_IRQACK
        move.b  %d0, REG_WATCHDOGW

        /* On reset, configure the game for demo mode */
        move.b  #1, BIOS_USER_MODE

        /* Switch to cart's ROMs (gfx, sound, vector table...) */
        move.b  #1, REG_SWPROM
        move.b  #1, REG_CRTFIX

        move    #0x2000, %sr
        bset    #7, BIOS_SYSTEM_MODE
        /* Call USER with args from BIOS_USER_REQUEST and BIOS_USER_MODE */
        jsr     USER.l

#if BIOS_ROM_HARDWARE != 0
        /* Save game's data to backup RAM at every reset */
        jsr     save_game_data_to_bram
#endif

        /* If there are no credits left, reset to demo mode */
        cmp.b   #0, BRAM_P1_CREDITS_BCD
        bne     .Lcredit_left
        move.b  #2, BIOS_USER_REQUEST
.Lcredit_left:
        /* Reset to demo mode */
        jmp     soft_reset


/**
 * Default VBlank handler
 */
impl_system_int1:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #4, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW
        rte


/**
 * Default Timer handler
 */
impl_system_int2:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #2, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW
        rte


/**
 * Return from USER subroutine
 * USER jmp to here, so the ret should go back
 * to to the last jsr USER done in function RESET
 */
impl_system_return:
        rts

/**
 * No-op function for not-implemented features
 */
impl_fix_clear:
impl_lst_1st:
impl_mess_out:
impl_controller_setup:
impl_noop:
        rts


impl_system_io:
        jsr     controllers_update_status
        jsr     credits_update_status
        jsr     credits_check_game_start

        rts



load_soft_dip:
        /* If this is the first time we see that ROM,
         * record its default DIP setting in the backup RAM */
        move.w  ROM_NGH, %d0
        cmp.w   SLOT1_NGH, %d0
        beq     .Lload_dip_from_bram
        move.w  %d0, SLOT1_NGH

#if BIOS_ROM_COUNTRY == 0
        move.l  DIP_JP_PTR, %d0
#elif BIOS_ROM_COUNTRY == 1
        move.l  DIP_SU_PTR, %d0
#else
        move.l  DIP_EU_PTR, %d0
#endif
        /* The DIP structure points to the ROM name,
         * skip it and move to DIP settings */
        add.l   #0x10, %d0
        movea.l %d0, %a0
        lea     SLOT1_SOFT_DIP, %a1
        moveq   #5, %d0
.Lcopy_first_dip_from_rom:
        move.b  (%a0)+, (%a1)+
        dbra    %d0, .Lcopy_first_dip_from_rom

        /* enum DIP must be processed to only keep the
         * default value configured for each DIP */
        moveq   #9, %d0
.Lcopy_enum_dip_from_rom:
        move.b  (%a0)+, %d1
        lsr     #4, %d1
        move.b  %d1, (%a1)+
        dbra    %d0, .Lcopy_enum_dip_from_rom

.Lload_dip_from_bram:
        lea     SLOT1_SOFT_DIP, %a0
        lea     BIOS_GAME_DIP, %a1
        moveq   #15, %d0
.Lcopy_dip_from_bram:
        move.b  (%a0)+, (%a1)+
        dbra    %d0, .Lcopy_dip_from_bram

        rts


load_game_data_from_bram:
        lea     SLOT1_BRAM_DATA, %a0
        movea.l ROM_BRAM_PTR, %a1
        move.w  ROM_BRAM_LEN, %d0
        cmpi.w  #0, %d0
        beq     .Lend_copy_from_bram
.Lcopy_from_bram:
        move.b  (%a0)+, (%a1)+
        dbra    %d0, .Lcopy_from_bram
.Lend_copy_from_bram:
        rts


save_game_data_to_bram:
        lea     SLOT1_BRAM_DATA, %a1
        movea.l ROM_BRAM_PTR, %a0
        move.w  ROM_BRAM_LEN, %d0
        cmpi.w  #0, %d0
        beq     .Lend_copy_to_bram
.Lcopy_to_bram:
        move.b  (%a0)+, (%a1)+
        dbra    %d0, .Lcopy_to_bram
.Lend_copy_to_bram:
        rts
