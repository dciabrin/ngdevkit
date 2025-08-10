/*
 * BIOS function stubs for linker allocation
 * Copyright (c) 2025 Damien Ciabrini
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

#include <ngdevkit/types.h>

// Configure those stub so they get allocated into a special code section
#define API_FUNC(name)                   \
__asm__ (".section .text.bios\n"         \
         ".global " #name "\n"           \
         ".type " #name ", @function\n"  \
         #name": .skip 6")

#define API_FUNC_ALIAS(name,alias)       \
__asm__ (".section .text.bios\n"         \
         ".global " #name "\n"           \
         ".type " #name ", @function\n"  \
         ".global " #alias "\n"          \
         ".type " #alias ", @function\n" \
         #alias":\n"                     \
         #name": .skip 6")

API_FUNC(BIOS_INIT_HARDWARE);

// Internal BIOS exception vector
//
API_FUNC(BIOS_EXC_BUS_ERROR);
API_FUNC(BIOS_EXC_ADDR_ERROR);
API_FUNC(BIOS_EXC_ILLEGAL_OP);
API_FUNC(BIOS_EXC_INVALID_OP);
API_FUNC(BIOS_EXC_TRACE);
API_FUNC(BIOS_EXC_FPU_EMU);
API_FUNC(BIOS_UNINITIALIZED_INT);
API_FUNC(BIOS_SPURIOUS_INT);

// BIOS public API
//
API_FUNC_ALIAS(bios_system_int1, SYSTEM_INT1);
API_FUNC_ALIAS(bios_system_int2, SYSTEM_INT2);
API_FUNC_ALIAS(bios_system_return, SYSTEM_RETURN);
API_FUNC_ALIAS(bios_system_io, SYSTEM_IO);
API_FUNC_ALIAS(bios_credit_check, CREDIT_CHECK);
API_FUNC_ALIAS(bios_credit_down, CREDIT_DOWN);
API_FUNC_ALIAS(bios_read_calendar, READ_CALENDAR);
API_FUNC_ALIAS(bios_setup_calendar, SETUP_CALENDAR);
API_FUNC_ALIAS(bios_card, CARD);
API_FUNC_ALIAS(bios_card_error, CARD_ERROR);
API_FUNC_ALIAS(bios_how_to_play, HOW_TO_PLAY);
API_FUNC_ALIAS(bios_checksum, CHECKSUM);
__asm__(".skip 66");
API_FUNC_ALIAS(bios_fix_clear, FIX_CLEAR);
API_FUNC_ALIAS(bios_lsp_1st, LSP_1st);
API_FUNC_ALIAS(bios_mess_out, MESS_OUT);
API_FUNC_ALIAS(bios_controller_setup, CONTROLLER_SETUP);

// CD-specific public API
//
__asm__(".skip 24");
API_FUNC_ALIAS(bios_cd_data_ready, CD_DATA_READY);
API_FUNC_ALIAS(bios_cd_data_transfer, CD_DATA_TRANSFER);
API_FUNC_ALIAS(bios_cd_unknown, CD_UNKNOWN);
