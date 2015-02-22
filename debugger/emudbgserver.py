#!/usr/bin/env python
# Copyright (c) 2015 Damien Ciabrini
# This file is part of ngdevkit
#
# ngdevkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# ngdevkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

"""GDB Server for emulators

Provide source level debugging for your ROM, controlled by a gdb client
"""

import re
import socket
from ctypes import *

class emudbg_api_t(Structure):
    """Debugger interface.
    Common operations to control the execution and the introspection
    of a ROM being executed through the emulator.
    """
    _fields_ = [
        ("api_identifier", c_int32),
        ("api_version", c_int32),
        ("fetch_byte", CFUNCTYPE(c_int32, c_int32)),
        ("store_byte", CFUNCTYPE(None, c_int32, c_int8)),
        ("fetch_register", CFUNCTYPE(c_int32, c_int32)),
        ("store_register", CFUNCTYPE(None, c_int32, c_int32)),
        ("add_breakpoint", CFUNCTYPE(None, c_int32)),
        ("del_breakpoint", CFUNCTYPE(None, c_int32)),
        ("clear_breakpoints", CFUNCTYPE(None))
    ]

class emudbg_cmd_t(Structure):
    """Debugger interface.
    Common operations to control the execution and the introspection
    of a ROM being executed through the emulator.
    """
    _fields_ = [
        ("next_run_command", c_int8),
        ("step_range_min", c_int32),
        ("step_range_max", c_int32)
    ]


class GDBServer(object):
    def __init__(self,host,port,api):
        self.api=api

        self.ack=True
        self.nextcmd=None

        self.host=host
        self.port=port
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((self.host, self.port))
        self.lsock=s
        self.conn=None

    def mkpacket(self,data):
        cksum=0
        for i in data: cksum=(cksum+ord(i)) & 0xff
        return "$%s#%02x"%(data,cksum)

    def process_H(self, cmd):
        """Set thread for subsequent operation.
        H op thread-id"""
        return self.mkpacket("OK")

    def process_qSupported(self, cmd):
#        return self.mkpacket("PacketSize=768;multiprocess+")
        return self.mkpacket("PacketSize=768")

    def process_qTStatus(self, cmd):
        """Is there a trace running right now"""
        return self.mkpacket("T0")

    def process_qTfV(self, cmd):
        """Get data about trace state variable (first)"""
        return self.mkpacket("l")

    def process_qTsV(self, cmd):
        """Get data about trace state variable (subsequent)"""
        return self.mkpacket("l")

    def process_qTfP(self, cmd):
        """Get data about trace points (first)"""
        return self.mkpacket("l")

    def process_qTsP(self, cmd):
        """Get data about trace points (subsequent)"""
        return self.mkpacket("l")

    def process_qfThreadInfo(self, cmd):
        """Get list of all active threads (first)"""
        return self.mkpacket("m0")

    def process_qsThreadInfo(self, cmd):
        """Get list of all active threads (subsequent)"""
        return self.mkpacket("l")

    def process_qAttached(self, cmd):
        """Attached to an existing process or created one"""
        return self.mkpacket("1")

    def process_qC(self, cmd):
        """Current thread-id"""
        return self.mkpacket("QC0")

    def process_qOffsets(self, cmd):
        """Get sections offsets (relocation)"""
        return self.mkpacket("TextSeg=00000000")

    def process_m(self, cmd):
        """Read length bytes of memory starting at address addr
        m addr,length"""
        m=re.match("m(.*),(.*)",cmd)
        addr, len = int(m.group(1),16), int(m.group(2),16)
        output=""
        for i in xrange(len):
            output+="%02x" % self.api.contents.fetch_byte(addr)
            addr+=1

        return self.mkpacket(output)

    def process_g(self, cmd):
        """Registers' values.
        Dump only d0, gdb will ask the other in sequence"""
        output="%08x" % self.api.contents.fetch_register(0)
        return self.mkpacket(output)

    def process_c(self, cmd):
        """Continue execution"""
        return None

    def process_p(self, cmd):
        """Read the value of register n
        p n
        d0..d7,a0..a5,fp,sp,sr,pc
        """
        regnum=int(cmd[1:],16)
        output="%08x" % self.api.contents.fetch_register(regnum)
        return self.mkpacket(output)

    def process_D(self, cmd):
        """Detach from the machine"""
        self.api.contents.clear_breakpoints()
        self.nextcmd.contents.next_run_command=ord('D')
        return self.mkpacket("OK")

    def process_qSymbol(self, cmd):
        """Serve symbol lookup request"""
        return self.mkpacket("OK")

    def process_QUESTIONMARK(self, cmd):
        """Why did the process stopped"""
        return self.mkpacket("S05")

    def process_vCont_QUESTIONMARK(self, cmd):
        """vCont supported? (thread continue)"""
        return self.mkpacket("vCont;c;C;s;S;t;r")

    def process_Z(self, cmd):
        """vCont supported? (thread continue)"""
        # only breakpoints are supported for the time being
        if cmd[1]!='0':
            return self.mkpacket("")
        m=re.match("Z.,(.*),",cmd)
        addr = int(m.group(1),16)
        self.api.contents.add_breakpoint(addr)
        return self.mkpacket("OK")

    def process_z(self, cmd):
        """vCont supported? (thread continue)"""
        # only breakpoints are supported for the time being
        if cmd[1]!='0':
            return self.mkpacket("")
        m=re.match("z.,(.*),",cmd)
        addr = int(m.group(1),16)
        self.api.contents.del_breakpoint(addr)
        return self.mkpacket("OK")

    def process_s(self, cmd):
        """step"""
        self.nextcmd.contents.next_run_command=ord('s')
        return None

    def process_vCont(self, cmd):
        """step"""
        # command can target a specific thread or not
        # get all actions for threads listed in the command
        thread={}
        actions=cmd.split(';')[1:]
        for a_t in actions:
            if ':' in a_t:
                a,tid=a_t.split(':')
                #t=tid.split('.')[1]
                t=tid
                if not thread.get(t): thread[t]=a
            else:
                if not thread.get('0'): thread['0']=a_t
        # pick the action for the (normally unique) thread
        # cont=thread[thread.keys()[0]]
        cont=thread['0']
        if cont[0]=='r':
            smin, smax=cont[1:].split(',')
            self.nextcmd.contents.step_range_min=int(smin,16)
            self.nextcmd.contents.step_range_max=int(smax,16)
        self.nextcmd.contents.next_run_command=ord(cont[0])
        return None

    def process_cmd(self, cmd):
        if cmd.startswith('qSupported:'):
            return self.process_qSupported(cmd)
        elif cmd.startswith('qTStatus'):
            return self.process_qTStatus(cmd)
        elif cmd.startswith('qTfV'):
            return self.process_qTfV(cmd)
        elif cmd.startswith('qTsV'):
            return self.process_qTsV(cmd)
        elif cmd.startswith('qTfP'):
            return self.process_qTfP(cmd)
        elif cmd.startswith('qTsP'):
            return self.process_qTsP(cmd)
        elif cmd.startswith('qfThreadInfo'):
            return self.process_qfThreadInfo(cmd)
        elif cmd.startswith('qsThreadInfo'):
            return self.process_qsThreadInfo(cmd)
        elif cmd.startswith('qAttached'):
            return self.process_qAttached(cmd)
        elif cmd.startswith('qC'):
            return self.process_qC(cmd)
        elif cmd.startswith('qOffsets'):
            return self.process_qOffsets(cmd)
        elif cmd.startswith('qSymbol::'):
            return self.process_qSymbol(cmd)
        elif cmd.startswith('g'):
            return self.process_g(cmd)
        elif cmd.startswith('p'):
            return self.process_p(cmd)
        elif cmd.startswith('c'):
            return self.process_c(cmd)
        elif cmd.startswith('m'):
            return self.process_m(cmd)
        elif cmd.startswith('?'):
            return self.process_QUESTIONMARK(cmd)
        elif cmd.startswith('vCont?'):
            return self.process_vCont_QUESTIONMARK(cmd)
        elif cmd.startswith('H'):
            return self.process_H(cmd)
        elif cmd.startswith('D'):
            return self.process_D(cmd)
        elif cmd.startswith('Z'):
            return self.process_Z(cmd)
        elif cmd.startswith('z'):
            return self.process_z(cmd)
        elif cmd.startswith('s'):
            return self.process_s(cmd)
        elif cmd.startswith('vCont;'):
            return self.process_vCont(cmd)
        else:
            return "+"

    def check_packet(self,data):
        expected=int(data[-2:],16)
        cksum=0
        for i in data[1:-3]: cksum=(cksum+ord(i)) & 0xff
        return cksum==expected

    def wait_for_client(self):
        self.lsock.listen(1)
        # collect fd from previous connection if needed
        if self.conn: self.conn.close()
        self.conn, self.addr=self.lsock.accept()

    def server_loop(self, emu_suspended=False, nextcmd=None):
        self.nextcmd = nextcmd
        if emu_suspended:
            # let's pretend it's been suspended by signal "Trap"
            packet=self.mkpacket("S05")
            self.conn.sendall(packet)
        while(True):
            # Read packet from GDB client
            data=self.conn.recv(1024)
            if not data: break
            # print "READ:", data

            # We may have received an interrupt request (CTRL-C)
            if data[0]=='\x03': data=data[1:]
            if data is '': continue

            # GDB seems to send an acknowledgment just after the initial
            # connection and after interrupt requests. Skip if present
            if data[0]=='+': data=data[1:]
            if data is '': continue

            # checksum and acknowledge packet
            chk=self.check_packet(data)
            self.conn.sendall('+')

            # process command in packet
            cmd=data[1:-3]
            packet=self.process_cmd(cmd)
            if not packet: break
            # print "SEND:",packet
            self.conn.sendall(packet)

            # wait for GDB to acknowledge the response
            data=self.conn.recv(1)
            # if data == '+':
            #     print "[ack]"
            # else:
            #     print "unexpected: ",data


server=None

def init_server(ptr):
    global server
    # For the time being, server is spawned on standard ports
    HOST, PORT = "127.0.0.1", 2159
    api=cast(ptr,POINTER(emudbg_api_t))
    server = GDBServer(HOST, PORT, api)
    f=server.lsock.fileno()
    return f

def wait_for_client():
    server.wait_for_client()
    f=server.conn.fileno()
    return f

def server_loop(emu_suspended, ptrnext):
    global server
    nextcmd=cast(ptrnext,POINTER(emudbg_cmd_t))
    server.server_loop(emu_suspended, nextcmd)


if __name__ == "__main__":
    print "Do not run emudbg server in standalone mode."
    print "See ngdevkit/debugger/README.md for more information."
    exit(1)
