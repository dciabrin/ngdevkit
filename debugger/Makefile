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

include ../Makefile.config

CC=gcc
INCFLAGS=
LDFLAGS=

INCFILES=emudbg.h

ifeq ($(shell uname), Darwin)
EXT=dylib
else
EXT=so
endif

OBJS=emudbg.o gdbserver.o
TARGET=libemudbg.$(EXT)

all: $(TARGET)

install: $(TARGET)
	cp $(TARGET) $(LOCALDIR)/lib
	cp $(INCFILES) $(LOCALDIR)/include

$(TARGET): $(OBJS)
	$(CC) -shared $^ -o $@ $(LDFLAGS)

%.o: %.c
	$(CC) -std=c99 $(INCFLAGS) -fPIC -g -c $< -o $@

emudbg_ctx.h: emudbg.h
emudbg.o: emudbg.c emudbg.h emudbg_ctx.h gdbserver.h
gdbserver.o: gdbserver.c gdbserver.h emudbg_ctx.h

clean:
	rm -f $(TARGET) *.o *~

.PHONY: install clean
