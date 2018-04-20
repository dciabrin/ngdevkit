/*
 * emudbg - emulator-agnostic source level debugging API
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

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#include "emudbg.h"
#include "emudbg_ctx.h"
#include "gdbserver.h"


#define DEFAULT_HOST "127.0.0.1"
#define DEFAULT_PORT 2159

int emudbg_init(struct emudbg_api_t *impl, void **emudbg_ctx)
{
    struct emudbg_ctx_t *ctx = malloc(sizeof(struct emudbg_ctx_t));
    ctx->listen_socket = FD_NONE;
    ctx->client_socket = FD_NONE;
    memset(ctx->data, 0, sizeof(ctx->data));
    memset(ctx->send_data, 0, sizeof(ctx->send_data));
    ctx->next_cmd_ptr = NULL;
    ctx->debugger_impl = impl;

    *emudbg_ctx = ctx;

    return 0;
}


int emudbg_wait_for_client(void *emudbg_ctx)
{
    struct emudbg_ctx_t *ctx=(struct emudbg_ctx_t*)emudbg_ctx;

    struct sockaddr_in listen_addr;
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_port = htons(DEFAULT_PORT);
    listen_addr.sin_addr.s_addr = inet_addr(DEFAULT_HOST);

    ctx->listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    bind(ctx->listen_socket, (struct sockaddr *)&listen_addr, sizeof(listen_addr));

    listen(ctx->listen_socket, 1);

    struct sockaddr client_addr;
    socklen_t addrlen;
    ctx->client_socket = accept(ctx->listen_socket, &client_addr, &addrlen);
}


int emudbg_client_command_pending(void *emudbg_ctx)
{
    struct emudbg_ctx_t *ctx=(struct emudbg_ctx_t*)emudbg_ctx;

    int bytes_avail=0;
    if (ctx->client_socket != FD_NONE) {
        ioctl(ctx->client_socket, FIONREAD, &bytes_avail);
        if (bytes_avail>0) {
            printf("bytes avail: %d\n",bytes_avail);
        }
    }
    return bytes_avail>0;
}


int emudbg_server_loop(void *emudbg_ctx, int emu_suspended, struct emudbg_cmd_t *next_cmd)
{
    return emudbg_gdb_server_loop(emudbg_ctx, emu_suspended, next_cmd);
}


void emudbg_disconnect_from_client(void *emudbg_ctx)
{
    struct emudbg_ctx_t *ctx=(struct emudbg_ctx_t*)emudbg_ctx;
    
    close(ctx->client_socket);
    ctx->client_socket;
    close(ctx->listen_socket);
    ctx->listen_socket;

    free(ctx);
}
