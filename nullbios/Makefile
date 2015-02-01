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
OBJCOPY=$(LOCALDIR)/bin/$(PREFIX)-objcopy

OBJS=biosstart
ELF=prom.elf

VERSION=0.1

bios: prom zrom srom mrom
	cd rom && /bin/echo -e "\
nullbios $(VERSION), an open source BIOS for Neo Geo\n\
http://github.com/dciabrin/ngdevkit\n\
." | zip -qz neogeo.zip *.lo *.s*

$(ELF):	$(OBJS:%=%.o)
	$(CC) -nostartfiles -T bios.ld $^ -o $(ELF)

%.o: %.S
	$(AS) -c $< -o $@

mrom:
	dd if=/dev/zero bs=1024 count=128 of=rom/sm1.sm1

srom:
	dd if=/dev/urandom bs=1024 count=128 of=rom/sfix.sfix

prom: $(ELF)
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/sp-s2.sp1

zrom:
	./zoom-rom.py -o rom/000-lo.lo

install: bios

clean:
	rm -f *.o *~ $(ELF) rom/*.*

.PHONY: install clean bios
