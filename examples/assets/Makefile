# Copyright (c) 2018 Damien Ciabrini
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

TILETOOL=$(LOCALDIR)/bin/tiletool.py

all: rom/s1.bin rom/c1.bin

smalltext.png:
	convert gfx/unscii8.png -crop 256x24+2+1 +repage -crop 8x8 +append +repage -background black -gravity east -extent 1024x8 smalltext.png

talltext.png:
	convert gfx/unscii16.png -crop 256x48+2+1 +repage -crop 8x16 +append +repage -background black -gravity east -extent 1024x16 talltext.png

srom.bmp: smalltext.png talltext.png
	./build-srom.py -s smalltext.png -t talltext.png -o srom.bmp

rom/s1.bin: rom srom.bmp
	$(TILETOOL) --fix -c srom.bmp -o rom/s1.bin

rom/c1.bin rom/c2.bin: rom
	$(TILETOOL) --sprite -c gfx/logo.png -o tmp.c1 tmp.c2 -s 1048576; \
	(dd bs=64 count=14 if=tmp.c1; dd bs=64 skip=15 if=tmp.c1; dd bs=64 count=1 if=/dev/zero) 2>/dev/null | cat >rom/c1.bin; \
	(dd bs=64 count=14 if=tmp.c2; dd bs=64 skip=15 if=tmp.c2; dd bs=64 count=1 if=/dev/zero) 2>/dev/null | cat >rom/c2.bin

clean:
	rm -f *.png tmp.* *.bmp *~ rom/*.*

rom:
	mkdir $@

.PHONY: clean
