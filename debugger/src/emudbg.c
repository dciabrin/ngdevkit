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

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "emudbg.h"
#include "emudbg_ctx.h"
#include "gdbserver.h"

#if defined(__WIN32__)
#include <ws2tcpip.h>
#define IOCTL ioctlsocket
#define BYTES_AVAIL_T u_long
#define NO_SOCKET_YET INVALID_SOCKET
#else
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#define IOCTL ioctl
#define BYTES_AVAIL_T int
#define NO_SOCKET_YET 0
#endif

#define DEFAULT_HOST "127.0.0.1"
#define DEFAULT_PORT 2159

int emudbg_init(struct emudbg_api_t *impl, void **emudbg_ctx)
{
#if defined(__WIN32__)
    WORD version;
    WSADATA data;
    version = MAKEWORD(2, 2);

    int err = WSAStartup(version, &data);
    if (err != 0) { return 1; }
#endif

    struct emudbg_ctx_t *ctx = malloc(sizeof(struct emudbg_ctx_t));
    ctx->listen_socket = NO_SOCKET_YET;
    ctx->client_socket = NO_SOCKET_YET;
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
    int r=0;
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_addr.s_addr = inet_addr(DEFAULT_HOST);
    listen_addr.sin_port = htons(DEFAULT_PORT);

    ctx->listen_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    r=bind(ctx->listen_socket, (struct sockaddr *)&listen_addr, sizeof(listen_addr));
    // printf("BOUND SOCKET: %x - %d (errno: %d)\n", ctx->listen_socket, r, EMUDBG_SOCKET_ERRNO);

    // printf("LISTEN:\n");
    r=listen(ctx->listen_socket, SOMAXCONN);
    // printf("LISTEN FINISHED: %d (errno: %d) - %d\n", r, EMUDBG_SOCKET_ERRNO, SOCKET_ERROR);

    struct sockaddr client_addr;
    socklen_t addrlen=sizeof(client_addr);
    ctx->client_socket = accept(ctx->listen_socket, &client_addr, &addrlen);
    // printf("ACCEPTED CLIENT SOCKET: %x (errno: %d)\n", ctx->client_socket, EMUDBG_SOCKET_ERRNO);

}


int emudbg_client_command_pending(void *emudbg_ctx)
{
    struct emudbg_ctx_t *ctx=(struct emudbg_ctx_t*)emudbg_ctx;

    BYTES_AVAIL_T bytes_avail=0;
    if (ctx->client_socket != FD_NONE) {
        IOCTL(ctx->client_socket, FIONREAD, &bytes_avail);
        if (bytes_avail>0) {
	  // printf("bytes avail: %d\n",bytes_avail);
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
