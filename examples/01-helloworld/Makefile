# Copyright (c) 2015-2017 Damien Ciabrini
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

include ../Makefile.common

OBJS=main
ELF=rom.elf

NULLSOUND=../../sound/nullsound
Z80HEX=$(NULLSOUND)/nullsound.ihx

all: cart

$(ELF):	$(OBJS:%=%.o)
	$(CC) $^ -o $@

%.o: %.c
	$(CC) -std=c99 -fomit-frame-pointer -g -c $< -o $@

mrom: rom
	$(MAKE) -C $(NULLSOUND) && \
	$(Z80OBJCOPY) -I ihex -O binary $(Z80HEX) rom/202-m1.m1 --pad-to 131072

vrom: rom
	dd if=/dev/zero bs=1024 count=512 of=rom/202-v1.v1

crom: rom
	cp $(ASSETS)/rom/c1.bin	rom/202-c1.c1; $(TRUNCATE) -s 1048576 rom/202-c1.c1; \
	cp $(ASSETS)/rom/c2.bin	rom/202-c2.c2; $(TRUNCATE) -s 1048576 rom/202-c2.c2

srom: rom
	cp $(ASSETS)/rom/s1.bin	rom/202-s1.s1; $(TRUNCATE) -s 1048576 rom/202-s1.s1

prom: $(ELF) rom
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/202-p1.p1

clean:
	rm -f *.png *.o *~ $(ELF) tmp.* rom/*.*

.PHONY: clean
