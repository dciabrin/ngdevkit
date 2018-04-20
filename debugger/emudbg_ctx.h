/*
 * emudbg - emulator-agnostic source level debugging API
 * Copyright (c) 2018 Damien Ciabrini
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

#ifndef __EMUDBG_CTX__
#define __EMUDBG_CTX__

#include "emudbg.h"

#define FD_NONE -1

struct emudbg_ctx_t {
    /// socket to listen to gdb clients
    int listen_socket;
    /// currently connected gdb client
    int client_socket;

    /// data received from gdb client
    char data[1024];
    /// Start of GDB packet content in data buffer (without '$')
    char *pkt_start;
    /// End of GDB packet content in data buffer (without CRC)
    char *pkt_end;
    /// data to be sent to gdb client
    char send_data[1024];

    /// data structure to tell the emulator what
    /// to run once we return from the command loop
    struct emudbg_cmd_t *next_cmd_ptr;

    /// emulator API to instrument the target
    struct emudbg_api_t *debugger_impl;
};

#endif /* __EMUDBG_CTX__ */
