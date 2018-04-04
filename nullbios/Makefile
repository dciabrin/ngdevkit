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
Z80OBJCOPY=$(LOCALDIR)/bin/sdobjcopy

OBJS=biosstart
ELF=prom.elf

NULLSOUND=../sound/nullsound
Z80HEX=$(NULLSOUND)/nullsound.ihx

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

mrom: rom
	$(MAKE) -C $(NULLSOUND) && \
	$(Z80OBJCOPY) -I ihex -O binary $(Z80HEX) rom/sm1.sm1 --pad-to 131072

srom: rom
	dd if=/dev/urandom bs=1024 count=128 of=rom/sfix.sfix

prom: $(ELF) rom
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/sp-s2.sp1

zrom: rom
	./zoom-rom.py -o rom/000-lo.lo

rom:
	mkdir $@

install: bios

clean:
	rm -f *.o *~ $(ELF) rom/*.*

.PHONY: install clean bios
