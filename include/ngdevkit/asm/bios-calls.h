/*
 * BIOS system calls
 * Copyright (c) 2020 Damien Ciabrini
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

#ifndef __NGDEVKIT_ASM_BIOS_CALLS_H__
#define __NGDEVKIT_ASM_BIOS_CALLS_H__


/* ROM entry point at reset */
#define BIOS_INIT_PC 0xc00402

/* BIOS exception routines */
#define BIOS_EXC_BUS_ERROR     0xc00408
#define BIOS_EXC_ADDR_ERROR    0xc0040e
#define BIOS_EXC_ILLEGAL_OP    0xc00414
#define BIOS_EXC_INVALID_OP    0xc0041a
#define BIOS_EXC_TRACE         0xc00420
#define BIOS_EXC_FPU_EMU       0xc00426
#define BIOS_UNINITIALIZED_INT 0xc0042c
#define BIOS_SPURIOUS_INT      0xc00432

/* BIOS interrupt functions */
#define SYSTEM_INT1 0xc00438
#define SYSTEM_INT2 0xc0043e

/* Return from BIOS call */
#define SYSTEM_RETURN 0xc00444

/* Update Inputs */
#define SYSTEM_IO 0xc0044a

/* MVS only: Credit checks */
#define CREDIT_CHECK 0xc00450
#define CREDIT_DOWN  0xc00456

/* MVS only: calendar functions */
#define READ_CALENDAR  0xc0045c
#define SETUP_CALENDAR 0xc00462

/* Card access */
#define CARD       0xc00468
#define CARD_ERROR 0xc0046e

/* "How to play" function */
#define HOW_TO_PLAY 0xc00474

/* Checksum */
#define CHECKSUM 0xc0047a

/* Graphic reset functions */
#define FIX_CLEAR 0xc004c2
#define LSP_1st   0xc004c8

/* Print function */
#define MESS_OUT 0xc004ce

/* Controller setup */
#define CONTROLLER_SETUP 0xc004d4


#endif /* __NGDEVKIT_ASM_BIOS_CALLS_H__ */
