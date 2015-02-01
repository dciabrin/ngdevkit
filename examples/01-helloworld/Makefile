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

include ../../Makefile.config

PREFIX=m68k-neogeo-elf
CC=$(LOCALDIR)/bin/$(PREFIX)-gcc
OBJCOPY=$(LOCALDIR)/bin/$(PREFIX)-objcopy
TILETOOL=$(LOCALDIR)/bin/tiletool.py

OBJS=main
ELF=rom.elf

cart: prom crom srom mrom vrom
	cd rom && for i in *.??; do ln -nsf $$i $${i%.*}.bin; done; \
	/bin/echo -e "\
http://github.com/dciabrin/ngdevkit\n\
." | zip -qz puzzledp.zip *.?? *.bin
	@echo "\n"Type \'make nullbios\' to copy the open source BIOS in ./rom

$(ELF):	$(OBJS:%=%.o)
	$(CC) $^ -o $@

%.o: %.c
	$(CC) -std=c99 -fomit-frame-pointer -c $< -o $@

mrom: rom
	dd if=/dev/zero bs=1024 count=128 of=rom/202-m1.m1

vrom: rom
	dd if=/dev/zero bs=1024 count=512 of=rom/202-v1.v1

crom: rom
	$(TILETOOL) --sprite -c gfx/logo.png -o tmp.c1 tmp.c2 -s 1048576; \
	(dd bs=64 count=14 if=tmp.c1; dd bs=64 skip=15 if=tmp.c1; dd bs=64 count=1 if=/dev/zero) 2>/dev/null | cat >rom/202-c1.c1; \
	(dd bs=64 count=14 if=tmp.c2; dd bs=64 skip=15 if=tmp.c2; dd bs=64 count=1 if=/dev/zero) 2>/dev/null | cat >rom/202-c2.c2

srom: rom
	convert gfx/Techno.png -gravity west -chop 1x0 -crop 9x9 +repage -gravity southeast -chop +8+8 +append +repage -gravity northwest -background black -splice $$((33*8))x0 "PNG8:font-8x8.png"
	$(TILETOOL) --fix -c font-8x8.png -o rom/202-s1.s1 -s 131072

prom: $(ELF) rom
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/202-p1.p1

clean:
	rm -f *.png *.o *~ $(ELF) tmp.* rom/*.*

nullbios:
	cp ../../nullbios/rom/neogeo.zip rom

rom:
	mkdir $@

.PHONY: cart nullbios clean
