/*
 * Copyright (c) 2026 Damien Ciabrini
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

#ifndef __NGDEVKIT_MEMORY_CARD_H__
#define __NGDEVKIT_MEMORY_CARD_H__

#include <stdbool.h>
#include <ngdevkit/types.h>
#include <ngdevkit/_utils.h>

#ifdef __cplusplus
extern "C" {
#endif


/**
 * Memory card command to be run by BIOS function `bios_card`
 */
extern u8 bios_card_command;

/* TODO: undocumented */
/* extern u8 bios_card_mode; */

/**
 * Error code returned by BIOS function `bios_card`
 */
extern u8 bios_card_answer;

/**
 * Pointer in RAM to hold memory card's save data
 */
extern u32 bios_card_start;

/**
 * Size of a memory card's save data
 */
extern u16 bios_card_size;

/**
 * NGH number to be used for the memory card's save data.
 * the number has a BCD representation
 */
extern u16 bios_card_fcb;

/**
 * Bitfield to reference the 16 possible save slot of a
 * particular game in the memory card.
 */
extern u16 bios_card_sub;


/**
 * Check whether a memory card is inserted into the system.
 */
bool ng_memory_card_inserted(void);

/**
 * Check whether the inserted memory card is write-protected.
 *
 * This function assumes that the memory card is already inserted.
 * Use `ng_memory_card_inserted` if you need to check it.
 */
bool ng_memory_card_write_protected(void);

/**
 * Allow writing to the memory card.
 *
 * Configure the status register to allow writes to the memory card.
 * This function must be called before running BIOS function
 * `bios_card` to allow it to write to the memory card.
 * After calling the BIOS function, the write status goes back
 * to 'locked' automatically.
 */
void ng_memory_card_unlock(void);

/**
 * Prevent writing to the memory card.
 *
 * Configure the status register to prevent writes to the memory card.
 * Note that the status is set to 'locked' automatically after
 * BIOS function `bios_card` ran a write command, so it is not
 * necessary to call this function directly.
 */
void ng_memory_card_lock(void);

/**
 * BIOS API: run a memory card command.
 *
 * Prior to calling this function, the command to be run must be
 * set in variable `bios_card_command`. If the command involves
 * writing to the memory card, you must unlock write access with
 * `ng_memory_card_unlock` prior to calling this BIOS function.
 *
 * Memory card commands read parameters from global variables.
 *  - `bios_card_start`: pointer to start of data in RAM
 *  - `bios_card_size`: size of transferred data
 *  - `bios_card_sub`: saved slot(s) for this game (bitfield)
 *  - `bios_card_fcb`: NGH number for this game (BCD format)
 *
 * The result of the BIOS call is an error code set in variable
 * `bios_card_answer`.
 *
 * More info at https://wiki.neogeodev.org/index.php?title=CARD
 */
void bios_card(void);

/**
 * Memory card command: format memory card
 * Inputs: N/A
 * Output: N/A
 */
#define MC_CMD_FORMAT 0x0

/**
 * Memory card command: number of saved entries for a game
 * Inputs:
 *  - `bios_card_fcb`: game NGH number
 * Output:
 * - `bios_card_sub`: a bit for every saved slot used for this game
 */
#define MC_CMD_DATA_SEARCH 0x1

/**
 * Memory card command: load data
 * Inputs:
 *  - `bios_card_fcb`: game NGH number
 *  - `bios_card_sub`: save slot to use (bit)
 *  - `bios_card_start`: address in RAM that will hold loaded data
 *  - `bios_card_size`: size of data to load (usually 64 bytes)
 * Output: N/A
 */
#define MC_CMD_LOAD_DATA 0x2

/**
 * Memory card command: save data
 * Inputs:
 *  - `bios_card_fcb`: game NGH number
 *  - `bios_card_sub`: save slot to use (bit)
 *  - `bios_card_start`: address in RAM of data to save
 *  - `bios_card_size`: size of data to save (usually 64 bytes)
 * Output: N/A
 */
#define MC_CMD_SAVE_DATA 0x3

/**
 * Memory card command: delete a specific save slot for a game
 * Inputs:
 *  - `bios_card_fcb`: game NGH number
 *  - `bios_card_sub`: save slot to delete (bit)
 * Output: N/A
 */

#define MC_CMD_DELETE_DATA 0x4

/**
 * Memory card command: TODO
 * Inputs: TODO
 * Output: TODO
 */
#define MC_CMD_DATA_TITLE 0x5

/**
 * Memory card command: set the memory card's user name
 * Inputs:
 *  - `bios_card_start`: user name's address in RAM
 * Output:
 */
#define MC_CMD_SAVE_USER_NAME 0x6

/**
 * Memory card command: get the memory card's user name
 * Inputs:
 *  - `bios_card_start`: user name's address in RAM
 * Output:
 */
#define MC_CMD_LOAD_USER_NAME 0x7


/**
 * Memory card answer
 *
 * Error code returned by a call to `bios_card`
 *  - 0x00: normal completion
 *  - 0x80: no card inserted
 *  - 0x81: card isn't formatted
 *  - 0x82: requested data does not exist
 *  - 0x83: FAT error
 *  - 0x84: card is full
 *  - 0x85: write disabled
 */
#define MC_ERR_OK 0x0
#define MC_ERR_NO_CARD 0x80
#define MC_ERR_NOT_FORMATTED 0x81
#define MC_ERR_DATA_DOES_NOT_EXIST 0x82
#define MC_ERR_FAT_ERROR 0x83
#define MC_ERR_CARD_FULL 0x84
#define MC_ERR_WRITE_DISABLED 0x85

/**
 * BIOS API: display memory card error and interactive recovery
 *
 * Let the BIOS present a human-readable status when a call to
 * `bios_card` returned an error.
 * Based on the error, the BIOS might present an interactive
 * menu to recover from the error (e.g. card full).
 *
 * More info at https://wiki.neogeodev.org/index.php?title=CARD
 */
void bios_card_error(void);



/* NOTE: we shadow the previous declarations with C macros, as some of
 * the BIOS functions do not preserve registers. This way, C code can
 * call the BIOS functions by their original name, while preserving
 * callee-saved registers as expected.
 */

#define bios_card() do { __SAVE_REGS_AND_CALL("%%d2-%%d7/%%a2-%%a6", bios_card); } while(0)


#ifdef __cplusplus
}
#endif

#endif /* __NGDEVKIT_MEMORY_CARD_H__ */
