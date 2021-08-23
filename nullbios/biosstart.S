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

#define ROM_NGH      0x108
#define DIP_JP_PTR   0x116
#define DIP_US_PTR   0x11a
#define DIP_EU_PTR   0x11e
#define USER         0x122
#define PLAYER_START 0x128
#define DEMO_END     0x12e
#define COIN_SOUND   0x134

#define COIN_DEPOSIT_PREVIOUS 0xd00020
#define COIN_DEPOSIT_CURRENT  0xd00021
#define P1_CREDITS_BCD        0xd00034
#define P2_CREDITS_BCD        0xd00035
#define SLOT1_NGH             0xd00124
#define SLOT1_SOFT_DIP        0xd00220


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
 * BIOS public calls, exported in a jmp table
 */
        .org    0x438
        jmp     SYSTEM_INT1.l           /* VBlank handler during boot     */
        jmp     SYSTEM_INT2.l           /* Timer handler                  */
        jmp     SYSTEM_RETURN.l         /* Return from USER subroutine    */
        jmp     SYSTEM_IO.l             /* Status of coins, joysticks...  */
        jmp     CREDIT_CHECK.l          /* Check credit for players       */
        jmp     CREDIT_DOWN.l           /* Decrement credits              */
        jmp     NO_OP                   /* READ_CALENDAR on MVS           */
        jmp     NO_OP                   /* SETUP_CALENDAR on MVS          */
        jmp     NO_OP                   /* CARD                           */
        jmp     NO_OP                   /* CARD_ERROR                     */
        jmp     NO_OP                   /* HOW_TO_PLAY                    */
        jmp     NO_OP                   /* CHECKSUM                       */
.if 0
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
        move.w  #7, REG_IRQACK
        move.b  %d0, REG_WATCHDOGW

        /* Set initial system information in RAM */

        /* Init credits information, and assume credits
         * are always stored in P1_CREDITS_BCD
         */
        move.b  #0, BIOS_STATCURNT
        move.b  #0, BIOS_STATCURNT_RAW
        move.b  #0, P1_CREDITS_BCD
#if BIOS_ROM_HARDWARE != 0
        move.b  #0x80, BIOS_MVS_FLAG
        jsr     load_soft_dip
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

        /* If there are no credits left, reset to demo mode */
        cmp.b   #0, P1_CREDITS_BCD
        bne     .Lcredit_left
        move.b  #2, BIOS_USER_REQUEST
.Lcredit_left:
        /* Reset to demo mode */
        jmp     soft_reset


/**
 * Default VBlank handler
 */
SYSTEM_INT1:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #4, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW
        rte


/**
 * Default Timer handler
 */
SYSTEM_INT2:
        /* Acknowlege IRQ, re-arm watchdog and return */
	move.w  #2, REG_IRQACK
	move.b  %d0, REG_WATCHDOGW
        rte


/**
 * Return from USER subroutine
 * USER jmp to here, so the ret should go back
 * to to the last jsr USER done in function RESET
 */
SYSTEM_RETURN:
        rts

/**
 * Ignore
 */
NO_OP:
        rts


SYSTEM_IO:
        /* player 1 input */
        move.b  BIOS_P1CURRENT, %d1
        move.b  %d1, BIOS_P1PREVIOUS
        move.b  REG_P1CNT, %d0
        not.b   %d0
        move.b  %d0, BIOS_P1CURRENT
        eor.b   %d0, %d1
        and.b   %d1, %d0
        move.b  %d0, BIOS_P1CHANGE

        /* player 2 input */
        move.b  BIOS_P2CURRENT, %d1
        move.b  %d1, BIOS_P2PREVIOUS
        move.b  REG_P2CNT, %d0
        not.b   %d0
        move.b  %d0, BIOS_P2CURRENT
        eor.b   %d0, %d1
        and.b   %d1, %d0
        move.b  %d0, BIOS_P2CHANGE

#if BIOS_ROM_HARDWARE != 0
        /* coin deposit status (only check P1 and P2)*/
        move.b  COIN_DEPOSIT_CURRENT, %d1
        move.b  %d1, COIN_DEPOSIT_PREVIOUS
        move.b  REG_STATUS_A, %d0
        not.b   %d0
        andi.b  #0x3, %d0
        move.b  %d0, COIN_DEPOSIT_CURRENT
        eor.b   %d0, %d1
        and.b   %d1, %d0
        move.b  %d0, 0x10fdd2
        /* %d0 has bits set to 1 for rising change */
        cmpi.b  #0, %d0
        beq     .Lnocoin_inserted
        /* when credit is inserted the following actions take place:
         *   . bump credit count
         *   . reset the compulsion start timer
         *   . call the game's "coin_sound" callback function
         * [only when the game is not running yet]
         *   . prepare a restart to game's title (user request 3)
         *   . reset the stack and soft reset to game's title
         */
        move.b  P1_CREDITS_BCD, %d1
        move.b  #1, %d0
        abcd    %d0, %d1
        move.b  %d1, P1_CREDITS_BCD
        move.b  #0x30, BIOS_COMPULSION_TIMER
        move.b  #60, BIOS_COMPULSION_FRAME_TIMER
        jsr     COIN_SOUND.l
        cmpi.b  #2, BIOS_USER_MODE
        beq     .Lstart_status
        move.b  #3, BIOS_USER_REQUEST
        lea.l   0x10f300, %sp
        pea.l   soft_reset
        rts
.Lnocoin_inserted:

        cmpi.b  #0, P1_CREDITS_BCD
        beq     .Lnostart
        /* decrement compulsory start timer */
        cmpi.b  #0, BIOS_COMPULSION_TIMER
        beq     .Lstart_pressed
        cmpi.b  #0, BIOS_COMPULSION_FRAME_TIMER
        bne     .Ldec_timer
        move.b  BIOS_COMPULSION_TIMER, %d1
        move.b  #1, %d0
        sbcd    %d0, %d1
        move.b  %d1, BIOS_COMPULSION_TIMER
        move.b  #60, BIOS_COMPULSION_FRAME_TIMER
.Ldec_timer:
        sub.b   #1, BIOS_COMPULSION_FRAME_TIMER
#endif

.Lstart_status:
        /* start status */
        move.b  REG_STATUS_B, %d0
        andi.b  #0xf, %d0
        not.b   %d0
        /* bits 1 and 3 from reg_status_b (start buttons)
         * to bit 1 and 2 in %d0 (for bios_start_flag)
         */
        move.b  %d0, %d1
        andi.b  #0x4, %d1
        lsr.b   #1, %d1
        andi.b  #0x1, %d0
        or.b    %d1, %d0
        move.b  BIOS_STATCURNT, %d1
        move.b  %d1, BIOS_STATCURNT_RAW
        move.b  %d0, BIOS_STATCURNT
        eor.b   %d0, %d1
        and.b   %d1, %d0
        move.b  %d0, BIOS_STATCHANGE
        cmpi.b  #0, %d0
        beq     .Lnostart
.Lstart_pressed:
        /* when start is pressed and credits are available:
         *   . game's "player_start" callback is executed
         *   . the callback sees which player wants to start
         *     via bits set in bios_start_flag
         *   . the callback engages "game mode" by
         *     setting bios_user_mode set to 2.
         * [only when game mode is engaged]
         *   . credits are decremented for each bit still set
         *     in bios_start_flag when the callback exits
         * [before the game is started - MVS only]
         *   . hitting 2UP start means that two players want
         *     to start, and it only runs the callback if
         *     enough credits are available
         */
#if BIOS_ROM_HARDWARE != 0
        cmp.b   #2, BIOS_USER_MODE
        beq     .Lend_of_coin_prechecks
        btst    #1, %d0
        beq     .L2up_no_pressed
        bset    #0, %d0
        cmp.b   #2, P1_CREDITS_BCD
        blt     .Lnostart
.L2up_no_pressed:
        cmp.b   #1, P1_CREDITS_BCD
        blt     .Lnostart
#endif
.Lend_of_coin_prechecks:
        move.b  %d0, BIOS_START_FLAG
        jsr     PLAYER_START.l
        cmp.b   #2, BIOS_USER_MODE
        bne     .Lnostart
#if BIOS_ROM_HARDWARE != 0
        jsr     CREDIT_DOWN.l
#endif
.Lnostart:
        rts


CREDIT_CHECK:
        /* TODO */
        rts


CREDIT_DOWN:
        move.b  #1, %d0
        btst.b  #0, BIOS_START_FLAG
        beq     .Lp1_not_running
        move.b  P1_CREDITS_BCD, %d1
        sbcd    %d0, %d1
        move.b  %d1, P1_CREDITS_BCD
.Lp1_not_running:
        btst.b  #1, BIOS_START_FLAG
        beq     .Lp2_not_running
        move.b  P1_CREDITS_BCD, %d1
        sbcd    %d0, %d1
        move.b  %d1, P1_CREDITS_BCD
.Lp2_not_running:
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
