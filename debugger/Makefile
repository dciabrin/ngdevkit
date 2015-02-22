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
INCFLAGS=$(shell python2.7-config --includes)
LDFLAGS=$(shell python2.7-config --libs)

SCRIPTS=emudbgserver.py
INCFILES=emudbg.h

ifeq ($(shell uname), Darwin)
EXT=dylib
else
EXT=so
endif

OBJS=emudbg.o
TARGET=libemudbg.$(EXT)

all: $(TARGET)

install: $(TARGET)
	cp $(TARGET) $(LOCALDIR)/lib
	cp $(INCFILES) $(LOCALDIR)/include
	cp $(SCRIPTS) $(LOCALDIR)/bin

$(TARGET): $(OBJS)
	$(CC) -shared $< -o $@ $(LDFLAGS)

emudbg.o: emudbg.c emudbg.h
	$(CC) $(INCFLAGS) -fPIC -g -c $< -o $@

clean:
	rm -f $(TARGET) *.o *~

.PHONY: install clean
