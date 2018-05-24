# Copyright (c) 2015-2018 Damien Ciabrini
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

SPRITES_IMGS=sprites/idle.gif sprites/walk.gif

all: cart

# fix up the transparent color on all GIFs
sprites/%.gif: gfx/spr_m_traveler_%_anim.gif sprites
	cp $< $@ ; \
	printf "\xff\x00\xff" | dd of=$@ bs=1 seek=13 count=3 conv=notrunc

# prepare the sprites for 64x64, and use same palette for all sprites
sprites/all.png: $(SPRITES_IMGS)
	convert  -alpha off -coalesce $^ -append +repage xc:'#ff00ff[64x1024!]' -compose dstover -composite PNG8:$@

sprites/all.c1: sprites/all.png sprites
	$(TILETOOL) --sprite -c $< -o $@ $(@:%.c1=%).c2

sprite.pal: sprites/all.png sprites
	$(PALTOOL) $< -o $@

$(ELF):	$(OBJS:%=%.o)
	$(CC) $^ -o $@

%.o: %.c
	$(CC) -std=gnu99 -fomit-frame-pointer -g -c $< -o $@

main.c: sprite.pal

mrom: rom
	$(MAKE) -C $(NULLSOUND) && \
	$(Z80OBJCOPY) -I ihex -O binary $(Z80HEX) rom/202-m1.m1 --pad-to 131072

vrom: rom
	dd if=/dev/zero bs=1024 count=512 of=rom/202-v1.v1

crom: rom sprites/all.c1
	cat $(ASSETS)/rom/c1.bin sprites/all.c1 > rom/202-c1.c1; $(TRUNCATE) -s 1048576 rom/202-c1.c1; \
	cat $(ASSETS)/rom/c2.bin sprites/all.c2 > rom/202-c2.c2; $(TRUNCATE) -s 1048576 rom/202-c2.c2

srom: rom
	cp $(ASSETS)/rom/s1.bin	rom/202-s1.s1; $(TRUNCATE) -s 1048576 rom/202-s1.s1

prom: $(ELF) rom
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/202-p1.p1

clean:
	rm -rf *.gif *.png *.pal *.o *~ $(ELF) tmp.* rom sprites

sprites:
	mkdir $@

.PHONY: clean
