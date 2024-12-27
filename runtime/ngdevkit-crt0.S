/*
 * Bootstrap code for Neo-Geo
 * Copyright (c) 2015-2024 Damien Ciabrini
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
#include <ngdevkit/asm/bios-calls.h>

#define VBLANK_IRQ 4
#define TIMER_IRQ  2

	.global rom_handler_VBlank_default
	.global rom_handler_Timer_default
	.global rom_mvs_startup_init_default
	.global rom_eye_catcher_default
	.global rom_game_default
	.global rom_title_default

_start:
        /* 68k exception vector table, 256 bytes
         * Common exceptions point to handlers implemented in the BIOS
         */
   	dc.l	0x10f300		/* Reset: Initial SSP		  */
        dc.l	BIOS_INIT_HARDWARE      /* Reset: Initial PC		  */
	dc.l	BIOS_EXC_BUS_ERROR    	/* Bus error			  */
	dc.l	BIOS_EXC_ADDR_ERROR     /* Address error		  */
	dc.l	BIOS_EXC_ILLEGAL_OP     /* Illegal instruction		  */
	dc.l	BIOS_EXC_INVALID_OP     /* Division by zero               */
	dc.l	BIOS_EXC_INVALID_OP     /* CHK instruction		  */
	dc.l	BIOS_EXC_INVALID_OP     /* TRAPV instruction		  */
	dc.l	BIOS_EXC_INVALID_OP	/* Privilege violation		  */
	dc.l	BIOS_EXC_TRACE		/* Trace			  */
	dc.l	BIOS_EXC_FPU_EMU	/* Line 1010 - FPU opcode emu     */
	dc.l	BIOS_EXC_FPU_EMU	/* Line 1111 - FPU opcode emu     */
	.fill	3,  4, 0xffffffff 	/* -- unassigned, reserved -- 	  */
	dc.l	BIOS_UNINITIALIZED_INT  /* Uninitialized interrupt vector */
#ifndef __NEO_GEO_CD__
	.fill	8,  4, 0xffffffff	/* -- unassigned, reserved --	  */
#else
        .fill	5,  4, 0xffffffff	/* -- unassigned, reserved --	  */
        dc.l    CD_DATA_READY           /* Vector 21: CD data ready       */
        dc.l    CD_DATA_TRANSFER        /* Vector 22: CD data transfer    */
        dc.l    CD_UNKNOWN              /* Vector 23: unknown?            */
#endif
        dc.l	BIOS_SPURIOUS_INT	/* Spurious interrupt             */
#ifndef __NEO_GEO_CD__
	dc.l	rom_handler_VBlank     	/* Lvl 1 autovector (VBlank IRQ)  */
	dc.l	rom_handler_Timer     	/* Lvl 2 autovector (Timer IRQ)   */
#else
        dc.l	rom_handler_Timer     	/* Lvl 1 autovector (Timer IRQ)   */
        dc.l	rom_handler_VBlank     	/* Lvl 2 autovector (VBlank IRQ)  */
#endif
        dc.l	0x00000000		/* Lvl 3 autovector (unused?)     */
	.fill	4,  4, 0x00000000	/* Lvl 4..7 autovectors (unused)  */
	.fill	16, 4, 0xffffffff	/* TRAP #n instruction (unused)   */
        .fill	8,  4, 0xffffffff	/* FPU errors (unused)	          */
        .fill	3,  4, 0xffffffff	/* MMU errors (unused)	          */
        .fill	5,  4, 0xffffffff	/* -- unassigned, reserved -- 	  */

	/* NEO-GEO Rom Header */
	.ascii	"NEO-GEO\0"		/* Magic bytes */
	dc.w	rom_NGH_ID		/* NGH number (cartridge UID) */
	dc.l	0x00100000              /* Program size in bytes */
	dc.l	rom_backup_data_address /* MVS: start of RAM to backup */
	dc.w	rom_backup_data_size    /* MVS: backup size */
	dc.b	rom_eye_catcher_mode    /* BIOS shows logo at startup */
        dc.b    0x00			/* 1st tile of the logo */

	/* Pointer to static Cartridge information (name, DIP, ...) */
	dc.l	dip_jp_rom
	dc.l	dip_us_rom
	dc.l	dip_eu_rom

	/* ROM Entry Point */
	jmp     USER.l
	jmp     PLAYER_START.l
	jmp     DEMO_END.l
	jmp     COIN_SOUND.l

	/* ...to be described... */
	.fill	70, 1, 0xff
	dc.w	0x0000

	/* Pointer to the Security Code (Unique sequence of 61 words) */
	dc.l	SCODE
SCODE:
	dc.w	0x7600, 0x4a6d, 0x0a14, 0x6600, 0x003c, 0x206d, 0x0a04, 0x3e2d
	dc.w	0x0a08, 0x13c0, 0x0030, 0x0001, 0x3210, 0x0c01, 0x00ff, 0x671a
	dc.w	0x3028, 0x0002, 0xb02d, 0x0ace, 0x6610, 0x3028, 0x0004, 0xb02d
	dc.w	0x0acf, 0x6606, 0xb22d, 0x0ad0, 0x6708, 0x5088, 0x51cf, 0xffd4
	dc.w	0x3607, 0x4e75, 0x206d, 0x0a04, 0x3e2d, 0x0a08, 0x3210, 0xe049
	dc.w	0x0c01, 0x00ff, 0x671a, 0x3010, 0xb02d, 0x0ace, 0x6612, 0x3028
	dc.w	0x0002, 0xe048, 0xb02d, 0x0acf, 0x6606, 0xb22d, 0x0ad0, 0x6708
	dc.w	0x5888, 0x51cf, 0xffd8, 0x3607, 0x4e75



/*
 * Default Vertical Blank interrupt handler
 * Used when no user function has been provided at link time
 */
rom_handler_VBlank_default:
        /* If BIOS is booting, do a tail call to the BIOS VBlank handler */
	btst    #7, BIOS_SYSTEM_MODE
        bne     .Lpost_bios_init.l
        jmp     SYSTEM_INT1.l
.Lpost_bios_init:

        /* This part is only called once BIOS init has ended and the C
	 * runtime has been loaded into memory (.Lboot). Calling C user
         * code below is thus safe.
         */
        /* Ack IRQ and rearm watchdog timer */

        move.w  #VBLANK_IRQ, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW

	/* If user handler exists for Vblank, call it */
	movem.l	%d0-%d7/%a0-%a7, -(%sp)
	move.l	#rom_callback_VBlank, %d0
	tst.l	%d0
	beq	.Ldone_Vblank
	move.l	%d0, %a0
	jsr	(%a0)
.Ldone_Vblank:
	jsr	SYSTEM_IO.l
	movem.l	(%sp)+, %d0-%d7/%a0-%a7
	rte


/*
 * Default Timer interrupt handler
 * Used when no user function has been provided at link time
 */
rom_handler_Timer_default:
        /* Ack IRQ and rearm watchdog timer */
        move.w  #TIMER_IRQ, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW
	/* If user handler exists for Hblank, call it */
	movem.l	%d0-%d7/%a0-%a7, -(%sp)
	move.l	#rom_callback_Timer, %d0
	tst.l	%d0
	beq	.Ldone_Hblank
	move.l	%d0, %a0
	jsr	(%a0)
.Ldone_Hblank:
	movem.l	(%sp)+, %d0-%d7/%a0-%a7
	rte


/*
 * MVS-only: run once when the cartridge is run for
 * the first time in the cabinet.
 * (in emulators like MAME, you can trigger that code
 *  by removing the nvram saved state)
 */
rom_mvs_startup_init_default:
        /* Rearm watchdog timer before init */
        move.b	%d0, REG_WATCHDOGW
        rts

/*
 * Load the data and BSS segments in RAM
 */
init_c_runtime:
	/* zero out BSS segment */
	moveq.l	#0, %d2
	moveq.l	#0, %d3
	moveq.l	#0, %d4
	moveq.l	#0, %d5
	moveq.l	#0, %d6
	moveq.l	#0, %d7
	movea.l	%d7, %a0
	movea.l	%d7, %a1

	movea.l	#__bss_start_in_ram, %a3
	move.l	#__bss_end, %d0
	sub.l	#__bss_start, %d0
	lsr.w	#5, %d0

.Lcopybss:
	movem.l	%d2-%d7/%a0-%a1, (%a3)
	lea.l	0x20(%a3), %a3
	dbra	%d0, .Lcopybss

	move.b	%d0, REG_WATCHDOGW /* kick watchdog */

	/* copy data segment from ROM to RAM */
	movea.l	#__data_start, %a2
	movea.l	#__data_start_in_ram, %a3
	move.l	#__data_end, %d0
	sub.l	#__data_start, %d0
	move.w	%d0, %d1
	lsr.w	#5, %d0
	andi.w	#0x001F, %d1
	bra	.Lcopydata_begin

.Lcopydata:
	movem.l	(%a2)+, %d2-%d7/%a0-%a1
	movem.l	%d2-%d7/%a0-%a1, (%a3)
	lea.l	0x20(%a3), %a3
.Lcopydata_begin:
	dbra	%d0, .Lcopydata

	/* copy last 0-31 bytes one at a time for cleanliness */
	bra	.Lcopylastdata_begin
.Lcopylastdata:
	move.b	(%a2)+, (%a3)+
.Lcopylastdata_begin:
	dbra	%d1, .Lcopylastdata

	move.b	%d0, REG_WATCHDOGW /* kick watchdog */

	rts

rom_title_default:
        /* Disable IRQs, as we don't want C code to be
         * called prior to runtime initialization
         */
        move    #0x2700, %sr

        /* Ack pending IRQ and rearm watchdog timer */
        move.w  #7, REG_IRQACK
        move.b  %d0, REG_WATCHDOGW

        /* Init the C part of the game cartridge */
        jsr init_c_runtime

        /* Switch to fix tiles from user bank */
        move.b	#1, REG_CRTFIX

        /* Enable interrupts and call game's main */
        move	#0x2000, %sr
        jsr	main_mvs_title.l

        /* if main returns, give back control to USER */
        rts

rom_eye_catcher_default:
rom_game_default:
        /* Disable IRQs, as we don't want C code to be
         * called prior to runtime initialization
         */
        move    #0x2700, %sr

        /* Ack pending IRQ and rearm watchdog timer */
        move.w  #7, REG_IRQACK
        move.b  %d0, REG_WATCHDOGW

        /* Init the C part of the game cartridge */
        jsr init_c_runtime

        /* Switch to fix tiles from user bank */
        move.b	#1, REG_CRTFIX

        /* Enable interrupts and call game's main */
        move	#0x2000, %sr
        jsr	main.l

        /* if main returns, give back control to USER */
        rts

/*
 * User request: main entry points, called by BIOS
 * When the symbols in the jump table below are not
 * implemented in the game cartridge, the linkscript
 * uses the default functions from this crt0 instead.
 */
.Luser_commands:
        dc.l    rom_mvs_startup_init  /* 0: StartupInit */
        dc.l	rom_eye_catcher       /* 1: EyeCatcher */
        dc.l	rom_game              /* 2: Game */
        dc.l	rom_title             /* 3: Title */
USER:
        /* Rearm watchdog */
        move.b	%d0, REG_WATCHDOGW

        /* Get user command requested by BIOS */
        clr.l	%d0
        move.b	BIOS_USER_REQUEST, %d0
        lsl.b	#2, %d0
        lea	.Luser_commands, %a0
        movea.l	(%a0,%d0),%a0

        /* Execute the command and go back to BIOS */
        jsr	(%a0)
        jmp	SYSTEM_RETURN


PLAYER_START:
	move.b  %d0, REG_WATCHDOGW
	movem.l	%d0-%d7/%a0-%a7, -(%sp)
	move.l	#player_start, %d0
	tst.l	%d0
	beq	.Lno_game_player_start
	move.l	%d0, %a0
	jsr	(%a0)
	jmp     .Ldone_start
/* TODO REMOVE THAT? */
.Lno_game_player_start:
        /* tell BIOS game didn't start */
        move.b  #0, %d0
        move.b  %d0, BIOS_START_FLAG
.Ldone_start:
	movem.l	(%sp)+, %d0-%d7/%a0-%a7
	rts


DEMO_END:
        rts


COIN_SOUND:
	move.b  %d0, REG_WATCHDOGW
	movem.l	%d0-%d7/%a0-%a7, -(%sp)
	move.l	#coin_sound, %d0
	tst.l	%d0
	beq	.Lcoin_sound_done
	move.l	%d0, %a0
	jsr	(%a0)
.Lcoin_sound_done:
	movem.l	(%sp)+, %d0-%d7/%a0-%a7
	rts


.Lidle:	bra	.Lidle

.Ldie:
	/* Basic procedure to signal that something went wrong
	 * in the program. Just switch to default fix bank and
	 * do nothing until a reset occurs.
	 */
	jmp	.Lidle.l
