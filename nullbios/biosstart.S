/*
 * nullbios - start of BIOS address space
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
        dc.b    0x0                     /* Pretend we are an AES HW */
        dc.b    0x0                     /* From EU */

/* The game cartridge's exception vectors point to a jump table
 * in the BIOS, handling boot and common exceptions
 */
GAME_CARTRIDGE_VECTORS:
        .rept   9
	jmp	RESET.l
        .endr

/*
 * BIOS public calls, exported in a jmp table
 */
        .org    0x438
        jmp     SYSTEM_INT1.l           /* VBlank handler during boot     */
        jmp     SYSTEM_INT2.l           /* Timer handler                  */
        jmp     SYSTEM_RETURN.l         /* Return from USER subroutine    */
.if 0
        jmp     SYSTEM_IO               /* Status of coins, joysticks...  */
        jmp     CREDIT_CHECK            /* Check credit for players       */
        jmp     CREDIT_DOWN             /* Decrement credits              */
        jmp     NO_OP                   /* READ_CALENDAR on MVS           */
        jmp     NO_OP                   /* SETUP_CALENDAR on MVS          */
        jmp     CARD
        jmp     CARD_ERROR
        jmp     HOW_TO_PLAY
        jmp     CHECKSUM

        .org    0x4c2
        jmp     FIX_CLEAR
        jmp     LSP_1st
        jmp     MESS_OUT
        jmp     CONTROLLER_SETUP
        jmp     NO_OP
.endif


        /* ... only code past this point ... */
        .org    0x4300


/**
 * Initialize the hardware and start user code
 */
RESET:
        /* Supervisor, init IRQ and watchdog timer */
        move    #0x2700, %sr
        move.w  #7, 0x3c000c
        move.b  %d0, 0x300001

        /* Prepare to call USER's request 0 (SystemInit) */
        clr     %d0
        move.b  %d0, 0x10fdae
        move.b  %d0, 0x10fdaf
        jsr     0x122

.Lsoft_reset:
        /* Switch to cart's ROMs (gfx, sound, vector table...) */
        move.b  #1, 0x3a0013
        move.b  #1, 0x3a001b

        /* Mark init as done, and start the GAME's main function
         * by calling USER's request 2 (Game)
         */
        move    #0x2000, %sr
        bset    #7, 0x10fd80
        move.b  #2, 0x10fdae
        move.b  #1, 0x10fdaf
        jmp.l   0x122

        /* Reset the game if it returned to the BIOS */
        jmp     .Lsoft_reset


/**
 * Default VBlank handler
 */
SYSTEM_INT1:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #4, 0x3c000c
	move.b  %d0, 0x300001
        rte


/**
 * Default Timer handler
 */
SYSTEM_INT2:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #2, 0x3c000c
	move.b  %d0, 0x300001
        rte


/**
 * Return from USER subroutine
 * USER jmp to here, so the ret should go back
 * to to the last jsr 0x122 done in function RESET
 */
SYSTEM_RETURN:
        rts

/**
 * Ignore
 */
NO_OP:
        rts
