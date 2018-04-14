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

include ../../Makefile.config

PREFIX=m68k-neogeo-elf
CC=$(LOCALDIR)/bin/$(PREFIX)-gcc
OBJCOPY=$(LOCALDIR)/bin/$(PREFIX)-objcopy
Z80OBJCOPY=$(LOCALDIR)/bin/sdobjcopy
TILETOOL=$(LOCALDIR)/bin/tiletool.py
PALTOOL=$(LOCALDIR)/bin/paltool.py

OBJS=main
ELF=rom.elf

ASSETS=../assets
NULLSOUND=../../sound/nullsound
Z80HEX=$(NULLSOUND)/nullsound.ihx

SPRITES_IMGS=sprites/idle.gif sprites/walk.gif

cart: assets mksprites prom crom srom vrom mrom
	cd rom && for i in *.??; do ln -nsf $$i $${i%.*}.bin; done; \
	/bin/echo -e "\
https://github.com/dciabrin/ngdevkit\n\
." | zip -qz puzzledp.zip *.?? *.bin
	@echo "\n"Type \'make nullbios\' to copy the open source BIOS in ./rom

mksprites: sprites sprites/all.c1 sprite.pal

# fix up the transparent color on all GIFs
sprites/%.gif: gfx/spr_m_traveler_%_anim.gif sprites
	cp $< $@ ; \
	printf "\xff\x00\xff" | dd of=$@ bs=1 seek=13 count=3 conv=notrunc

# prepare the sprites for 64x64, and use same palette for all sprites
sprites/all.png: $(SPRITES_IMGS)
	convert  -alpha off -coalesce $^ -append +repage xc:'#ff00ff[64x1024!]' -compose dstover -composite PNG8:$@

sprites/all.c1: sprites/all.png
	$(TILETOOL) --sprite -c $< -o $@ $(@:%.c1=%).c2

sprite.pal: sprites/all.png
	$(PALTOOL) $< -o $@

$(ELF):	$(OBJS:%=%.o)
	$(CC) $^ -o $@

%.o: %.c
	$(CC) -std=gnu99 -fomit-frame-pointer -g -c $< -o $@

mrom: rom
	$(MAKE) -C $(NULLSOUND) && \
	$(Z80OBJCOPY) -I ihex -O binary $(Z80HEX) rom/202-m1.m1 --pad-to 131072

vrom: rom
	dd if=/dev/zero bs=1024 count=512 of=rom/202-v1.v1

crom: rom
	cat $(ASSETS)/rom/c1.bin sprites/all.c1 > rom/202-c1.c1; truncate -s 1048576 rom/202-c1.c1; \
	cat $(ASSETS)/rom/c2.bin sprites/all.c2 > rom/202-c2.c2; truncate -s 1048576 rom/202-c2.c2

srom: rom
	cp $(ASSETS)/rom/s1.bin	rom/202-s1.s1; truncate -s 1048576 rom/202-s1.s1

prom: $(ELF) rom
	$(OBJCOPY) -O binary -S -R .comment --reverse-bytes=2 $< rom/202-p1.p1

clean:
	rm -rf *.gif *.png *.pal *.o *~ $(ELF) tmp.* rom sprites

nullbios:
	cp ../../nullbios/rom/neogeo.zip rom

assets:
	$(MAKE) -C $(ASSETS) all

sprites rom:
	mkdir $@

gngeo:
	$(LOCALDIR)/bin/gngeo -b glsl --scale 3 --no-resize --shaderpath=$(LOCALDIR)/../toolchain/qcrt-glsl --shader qcrt-flat.glslp -i rom puzzledp

gngeo-fullscreen:
	$(LOCALDIR)/bin/gngeo -b glsl --fullscreen --scale 5 --no-resize --shaderpath=$(LOCALDIR)/../toolchain/qcrt-glsl --shader qcrt-flat.glslp -i rom puzzledp

.PHONY: cart assets nullbios clean gngeo gngeo-fullscreen
