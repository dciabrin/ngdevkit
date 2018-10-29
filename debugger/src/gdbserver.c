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


#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "emudbg.h"
#include "emudbg_ctx.h"

#if defined(__WIN32__)
#include <ws2tcpip.h>
#else
#include <sys/types.h>
#include <sys/socket.h>
#endif


#ifndef DBG
#define DBG(x, ...)
#endif

int check_packet(char *pkt_start, char *pkt_end)
{
    // TODO
    return 0;
}

///
int make_packet(struct emudbg_ctx_t *ctx, unsigned char* msg)
{
    unsigned char chksum = 0;
    char *out = ctx->send_data;
    *out++ = '$';
    while (*msg != 0) {
        chksum=(chksum+*msg)&0xff;
        *out++ = *msg++;
    }
    int written = snprintf(out, 4, "#%02x", chksum);
    return (out+written - ctx->send_data);
}


/// Set thread for subsequent operation.
/// H op thread-id
int process_H(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "OK");
}

/// Options supported by this GDB server implementation
int process_qSupported(struct emudbg_ctx_t *ctx)
{
    // return make_packet(ctx, "PacketSize=768;multiprocess+");
    return make_packet(ctx, "PacketSize=768");
}

/// Is there a trace running right now
int process_qTStatus(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "T0");
}

/// Get data about trace state variable (first)
int process_qTfV(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "l");
}

/// Get data about trace state variable (subsequent)
int process_qTsV(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "l");
}

/// Get data about trace points (first)
int process_qTfP(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "l");
}

/// Get data about trace points (subsequent)
int process_qTsP(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "l");
}

/// Get list of all active threads (first)
int process_qfThreadInfo(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "m0");
}

/// Get list of all active threads (subsequent)
int process_qsThreadInfo(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "l");
}

/// Attached to an existing process or created one
int process_qAttached(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "1");
}

/// Current thread-id
int process_qC(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "QC0");
}

/// Get sections offsets (relocation)
int process_qOffsets(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "TextSeg=00000000");
}

/// Read length bytes of memory starting at address addr
/// $m{hex-address},{length}#{crc}
int process_m(struct emudbg_ctx_t *ctx)
{
    char *addr_str=ctx->pkt_start+1;
    int addr = (int)strtoul(addr_str, NULL, 16);
    char *len_str=strchr(ctx->pkt_start,',')+1;
    int len = (int)strtoul(len_str, NULL, 10);
    // support up to 4bytes read
    static char buffer[9];
    char *output=buffer;
    for (int i=0; i<len; i++, addr++, output+=2) {
        snprintf(output, 3, "%02x", ctx->debugger_impl->fetch_byte(addr));
    }
    return make_packet(ctx, buffer);
}

/// Registers' values.
/// Dump only d0, gdb will ask the other in sequence
int process_g(struct emudbg_ctx_t *ctx)
{
    static char output[9];
    snprintf(output, sizeof(output), "%08x", ctx->debugger_impl->fetch_register(0));
    return make_packet(ctx, output);
}

/// Read the value of register n
/// p n
/// d0..d7,a0..a5,fp,sp,sr,pc
int process_p(struct emudbg_ctx_t *ctx)
{
    int reg = (int)strtoul(ctx->pkt_start+1, NULL, 16);
    static char output[9];
    snprintf(output, sizeof(output), "%08x", ctx->debugger_impl->fetch_register(reg));
    return make_packet(ctx, output);
}

/// Continue execution
int process_c(struct emudbg_ctx_t *ctx)
{
    return 0;
}

/// Detach from the machine
int process_D(struct emudbg_ctx_t *ctx)
{
    ctx->next_cmd_ptr->next_run_command = 'D';
    return make_packet(ctx, "OK");
}

/// Serve symbol lookup request
int process_qSymbol(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "OK");
}

/// Why did the process stopped
int process_QUESTIONMARK(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "S05");;
}

/// vCont supported? (thread continue)
int process_vCont_QUESTIONMARK(struct emudbg_ctx_t *ctx)
{
    return make_packet(ctx, "vCont;c;C;s;S;t;r");
}

/// create breakpoint
int process_Z(struct emudbg_ctx_t *ctx)
{
    // only breakpoints are supported for the time being
    if (*(ctx->pkt_start+1) != '0') {
        return make_packet(ctx, "");
    }
    char *start_addr = strchr(ctx->pkt_start, ',')+1;
    int addr = (int)strtoul(start_addr, NULL, 16);
    ctx->debugger_impl->add_breakpoint(addr);
    return make_packet(ctx, "OK");
}

/// delete breakpoint
int process_z(struct emudbg_ctx_t *ctx)
{
    // only breakpoints are supported for the time being
    if (*(ctx->pkt_start+1) != '0') {
        return make_packet(ctx, "");
    }
    char *start_addr = strchr(ctx->pkt_start, ',')+1;
    int addr = (int)strtoul(start_addr, NULL, 16);
    ctx->debugger_impl->del_breakpoint(addr);
    return make_packet(ctx, "OK");
}

/// step
int process_s(struct emudbg_ctx_t *ctx)
{
    ctx->next_cmd_ptr->next_run_command = 's';
    return 0;
}

/// step
int process_vCont(struct emudbg_ctx_t *ctx)
{
    // TODO parse real step command
    char *vCont_action = strchr(ctx->pkt_start, ';')+1;
    char cont_cmd = *vCont_action;
    if (cont_cmd == 'r') {
        char *smin_str = vCont_action+1;
        char *smax_str = strchr(smin_str, ',')+1;
        ctx->next_cmd_ptr->step_range_min = (int)strtoul(smin_str, NULL, 16);
        ctx->next_cmd_ptr->step_range_max = (int)strtoul(smax_str, NULL, 16);
    }
    ctx->next_cmd_ptr->next_run_command = cont_cmd;
    return 0;
}


#define STARTS_WITH(ptr, str) (!strncmp((ptr), (str), sizeof(str)-1))

/// packet dispatcher
int process_packet(struct emudbg_ctx_t *ctx)
{
    if (STARTS_WITH(ctx->pkt_start, "qSupported:")) {
        return process_qSupported(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qTStatus")) {
        return process_qTStatus(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qTfV")) {
        return process_qTfV(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qTsV")) {
        return process_qTsV(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qTfP")) {
        return process_qTfP(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qTsP")) {
        return process_qTsP(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qfThreadInfo")) {
        return process_qfThreadInfo(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qsThreadInfo")) {
        return process_qsThreadInfo(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qAttached")) {
        return process_qAttached(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qC")) {
        return process_qC(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qOffsets")) {
        return process_qOffsets(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "qSymbol::")) {
        return process_qSymbol(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "g")) {
        return process_g(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "p")) {
        return process_p(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "c")) {
        return process_c(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "m")) {
        return process_m(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "?")) {
        return process_QUESTIONMARK(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "vCont?")) {
        return process_vCont_QUESTIONMARK(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "H")) {
        return process_H(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "D")) {
        return process_D(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "Z")) {
        return process_Z(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "z")) {
        return process_z(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "s")) {
        return process_s(ctx);
    } else if (STARTS_WITH(ctx->pkt_start, "vCont;")) {
        return process_vCont(ctx);
    } else {
        ctx->send_data[0]='+';
        return 1;
    }
}


int emudbg_gdb_server_loop(void *emudbg_ctx, int emu_suspended, struct emudbg_cmd_t *next_cmd)
{
    struct emudbg_ctx_t *ctx=(struct emudbg_ctx_t*)emudbg_ctx;
    ctx->next_cmd_ptr = next_cmd;

    if (emu_suspended) {
        int len = make_packet(ctx, "S05");
        send(ctx->client_socket, ctx->send_data, len, 0);
    }

    while (true) {
        // Read packet from GDB client
        int len_recv = recv(ctx->client_socket, ctx->data, 1024, 0);
        if (!len_recv) break;
	if (len_recv == -1) {
	  DBG("READ ERROR: %x - %d\n", ctx->client_socket, EMUDBG_SOCKET_ERRNO);
	  break;
	}
        ctx->data[len_recv] = '\0';
	DBG("READ: %s - %d\n", ctx->data, len_recv);

        char *pos = ctx->data;
        char *end = pos + len_recv;
        // We may have received an interrupt request (CTRL-C)
        if (*pos == 0x03) pos++;
        if (pos == end) continue;

        // GDB seems to send an acknowledgment just after the initial
        // connection and after interrupt requests. Skip if present
        if (*pos == '+') pos++;
        if (pos == end) continue;

        // TODO checksum and acknowledge packet
        int chk = check_packet(pos, ctx->data+len_recv);
        send(ctx->client_socket, "+", 1, 0);

        // process command in packet
        ctx->pkt_start = pos+1;
        ctx->pkt_end = end-3;
        int return_pkt_len = process_packet(ctx);
        if (return_pkt_len) {
	  DBG("SEND: %s - %d\n",ctx->send_data, return_pkt_len);

	    send(ctx->client_socket, ctx->send_data, return_pkt_len, 0);
            // wait for GDB to acknowledge the response
            int len_recv = recv(ctx->client_socket, ctx->data, 1, 0);
            ctx->data[len_recv] = 0;
            DBG("RECV: %s - %d\n", ctx->data, len_recv);
        } else {
            // gdb requested the to resume execution finish this loop
            // and go back to the emulator with the resume action to
            // perform (continue, setp over, step in...).
            break;
        }
    }

    return 0;
}
