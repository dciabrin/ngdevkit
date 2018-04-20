/*
 * emudbg - emulator-agnostic source level debugging API
 * Copyright (c) 2015-2018 Damien Ciabrini
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

#ifndef __EMUDBG_H__
#define __EMUDBG_H__

#include <stdint.h>

#define API_ID            0x4442475a

/**
 * Source level debugging API
 * Expose the basic actions which are needed to instrument
 * the execution of a ROM running under an emulator.
 *
 * The emulator must provide an implementation of this interface
 * to the debugging server so that it can be targeted by GDB or
 * other debuggers which implement GDB's Remote Serial Protocol
 */
struct emudbg_api_t {
    uint32_t api_identifier;
    uint32_t version_supported;

    /** Data access */
    uint8_t (*fetch_byte)(uint32_t addr);
    void (*store_byte)(uint32_t addr, uint8_t value);

    /** Register access */
    uint32_t (*fetch_register)(uint32_t num);
    void (*store_register)(uint32_t num, uint32_t value);

    /** Breakpoint */
    void (*add_breakpoint)(uint32_t addr);
    void (*del_breakpoint)(uint32_t addr);
    void (*clear_breakpoints)();
};

/**
 * Next run state to be executed by the emulator
 */
struct emudbg_cmd_t {
    /** Next run command to execute: continue, step range... */
    uint8_t  next_run_command;
    /** Range restriction for the next run command */
    uint32_t step_range_min, step_range_max;
};


/**
 * Initialize the remote debugger API
 * @param impl the set of debugging features that must \
 *             be implemented by the emulator
 * @return initialization status
 */
int emudbg_init(struct emudbg_api_t *impl, void **emudbg_ctx);

/**
 * Wait for an incoming connection from a remote debugger
 * @return state of the connection
 */
int emudbg_wait_for_client(void *emudbg_ctx);

/**
 * Check for pending command issued by the remote debugger
 * @return whether there are pending data from the remote debugger
 */
int emudbg_client_command_pending(void *emudbg_ctx);

/**
 * Go into debugger interactive loop
 * @param emu_suspended whether the emulation has been suspended \
 *        (e.g. breakpoint hit)
 * @parm next_cmd action to be performed by the emulator \
 *                (continue, step range...) as requested by \
 *                the remote debugger
 * @return status of the remote loop
 */
int emudbg_server_loop(void *emudbg_ctx, int emu_suspended, struct emudbg_cmd_t *next);

/**
 * Clean debugging session associated with a disconnected remote debugger
 */
void emudbg_disconnect_from_client(void *emudbg_ctx);

#endif /* __EMUDBG_H__ */
