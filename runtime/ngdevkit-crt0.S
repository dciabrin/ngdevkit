/*
 * Bootstrap code for Neo-Geo
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

	.global	rom_info_default
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
	dc.l	0xc00402        	/* Reset: Initial PC		  */
	dc.l	0xc00408               	/* Bus error			  */
	dc.l	0xc0040e                /* Address error		  */
	dc.l	0xc00414	        /* Illegal instruction		  */
	dc.l	0xc0041a                /* Division by zero               */
	dc.l	0xc0041a                /* CHK instruction		  */
	dc.l	0xc0041a	        /* TRAPV instruction		  */
	dc.l	0xc0041a		/* Privilege violation		  */
	dc.l	0xc00420		/* Trace			  */
	dc.l	0xc00426		/* Line 1010 - FPU opcode emu     */
	dc.l	0xc00426		/* Line 1111 - FPU opcode emu     */
	.fill	3,  4, 0xc00426 	/* -- unassigned, reserved -- 	  */
	dc.l	0xc0042c		/* Uninitialized interrupt vector */
	.fill	8,  4, 0xffffffff	/* -- unassigned, reserved --	  */
	dc.l	0xc00432		/* Spurious interrupt		  */
	dc.l	rom_handler_VBlank     	/* Lvl 1 autovector (VBlank IRQ)  */
	dc.l	rom_handler_Timer     	/* Lvl 2 autovector (Timer IRQ)   */
 	dc.l	0x00000000		/* Lvl 3 autovector (Cold reset)  */
	.fill	4,  4, 0x00000000	/* Lvl 4..7 autovectors (unused)  */
	.fill	16, 4, 0xffffffff	/* TRAP #n instruction (unused)   */
	.fill	7,  4, 0xffffffff	/* FPU errors (unused)	          */
	dc.l	0xffffffff	        /* -- unassigned, reserved -- 	  */
	.fill	3,   4, 0xffffffff	/* MMU errors (unused)	          */
	.fill	5,   4, 0xffffffff	/* -- unassigned, reserved -- 	  */

	/* NEO-GEO Rom Header */
	.ascii	"NEO-GEO\0"		/* Magic bytes */
	dc.w	rom_NGH_ID		/* NGH number (cartridge UID) */
	dc.l	0x00100000              /* Program size in bytes */
	dc.l	0x00100000		/* Debug DIP pointer */
	dc.w   	0x0000                  /* Size of DIP data */
	dc.b	rom_eye_catcher_mode    /* BIOS shows logo at startup */
        dc.b    0x00			/* 1st tile of the logo */

	/* Pointer to static Cartridge information (name, DIP, ...) */
	dc.l	rom_info_JP
	dc.l	rom_info_US
	dc.l	rom_info_EU

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

rom_info_default:
	/* Default ROM name */
	.ascii	"ngdevkit ROM    "
	/* ROM DIP switches */
	dc.w	0xffff
	dc.w	0xffff
	dc.w	0xff64
	.fill	10,1,0
	.ascii  "Dummy switch"


/*
 * Default Vertical Blank interrupt handler
 * Used when no user function has been provided at link time
 */
rom_handler_VBlank_default:
	/* If BIOS is booting, forward to the BIOS VBlank handler */
	btst    #7, 0x10fd80
	bne     .Ldisplayed.l
	move.l  #0xc00438, %a0
	jmp     (%a0)

        /* This part is only called once BIOS init has ended and the C
	 * runtime has been loaded into memory (.Lboot). Calling C user
         * code below is thus safe.
         */
.Ldisplayed:
        /* Ack IRQ and rearm watchdog timer */

	move.w  #4, 0x3c000c
	move.b  %d0, 0x300001

	/* If user handler exists for Vblank, call it */
	movem.l	%d0-%d7/%a0-%a7, -(%sp)
	move.l	#rom_callback_VBlank, %d0
	tst.l	%d0
	beq	.Ldone_Vblank
	move.l	%d0, %a0
	jsr	(%a0)
.Ldone_Vblank:
	movem.l	(%sp)+, %d0-%d7/%a0-%a7
	rte


/*
 * Default Timer interrupt handler
 * Used when no user function has been provided at link time
 */
rom_handler_Timer_default:
        /* Ack IRQ and rearm watchdog timer */
	move.w  #2, 0x3c000c
	move.b  %d0, 0x300001
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
        move.b	%d0, 0x300001
        rts

/*
 * Load the data and BSS segments in RAM
 */
init_c_runtime:
	/* copy data segment from ROM to RAM */
	move.l	#__data_end, %d0
	sub.l	#__data_start, %d0
	movea.l	#__data_start, %a0
	movea.l	#0x100000, %a1
	tst	%d0
	beq	.Lclearbss
.Lcopydata:
	move.b	(%a0)+, (%a1)+
	move.b	%d0, 0x300001
	dbra	%d0, .Lcopydata

.Lclearbss:
	/* Zero out bss segment */
	move.l	#__data_end, %d0
	sub.l	#__data_start, %d0
	add.l	#0x100000, %d0
	movea.l	%d0, %a0
	move.l	#__bss_end, %d0
	sub.l	#__bss_start, %d0
	tst	%d0
	beq	.Linitdone
.Lcopybss:
	move.b	#0, (%a0)+
	move.b	%d0, 0x300001
	dbra	%d0, .Lcopybss

.Linitdone:
        rts


rom_eye_catcher_default:
rom_game_default:
rom_title_default:
        /* Disable IRQs, as we don't want C code to be
         * called prior to runtime initialization
         */
        move    #0x2700, %sr

        /* Ack pending IRQ and rearm watchdog timer */
        move.w  #7, 0x3c000c
        move.b  %d0, 0x300001

        /* Init the C part of the game cartridge */
        jsr init_c_runtime

        /* Switch to fix tiles from user bank */
        move.b	#1, 0x3a001b

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
        move.b	%d0, 0x300001

        /* Get user command requested by BIOS */
        clr.l	%d0
        move.b	0x10fdae, %d0
        lsl.b	#2, %d0
        lea	.Luser_commands, %a0
        movea.l	(%a0,%d0),%a0

        /* Execute the command and go back to BIOS */
        jsr	(%a0)
        jmp	0xc00444


PLAYER_START:
        rts


DEMO_END:
        rts


COIN_SOUND:
        rts


.Lidle:	bra	.Lidle

.Ldie:
	/* Basic procedure to signal that something went wrong
	 * in the program. Just switch to default fix bank and
	 * do nothing until a reset occurs.
	 */
	jmp	.Lidle.l
