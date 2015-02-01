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

PREFIX=m68k-neogeo-elf
CC=$(LOCALDIR)/bin/$(PREFIX)-gcc
AS=$(LOCALDIR)/bin/$(PREFIX)-gcc
AR=$(LOCALDIR)/bin/$(PREFIX)-ar
RANLIB=$(LOCALDIR)/bin/$(PREFIX)-ranlib

TARGETS=libsyscalls.a crt0.o

all: $(TARGETS)

install: $(TARGETS)
	cp -f $^ ngdevkit.ld $(LOCALDIR)/$(PREFIX)/lib; \
	ver=`$(CC) -dumpspecs | grep -A1 \*version: | tail -1`; \
	$(CC) -dumpspecs | sed -e 's/\(-lc\)/\1 -lsyscalls/' | \
	sed -e 's/\(crtbegin.o%s\)/-T ngdevkit.ld%s \1/' > \
	$(LOCALDIR)/lib/gcc/$(PREFIX)/$$ver/specs

libsyscalls.a: syscalls.o
	$(AR) cru $@ $^ && $(RANLIB) $@ 

%.o: %.c
	$(CC) -std=c99 -fomit-frame-pointer -c $< -o $@

%.o: %.S
	$(AS) -c $< -o $@

clean:
	rm -f *.o *~ *.a

.PHONY: install clean
