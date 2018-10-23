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

# Install dir, GNU mirrors...
include Makefile.config

# Version of external dependencies
SRC_BINUTILS=binutils-2.25
SRC_GCC=gcc-5.5.0
SRC_NEWLIB=newlib-1.14.0
SRC_GDB=gdb-7.8.2
SRC_SDCC=sdcc-src-3.7.0

all: \
	download-toolchain \
	unpack-toolchain \
	build-compiler \
	build-debugger \
	build-tools \
	download-emulator \
	build-emulator \
	build-emulator-config \
	download-shaders

download-toolchain: \
	toolchain/$(SRC_BINUTILS).tar.bz2 \
	toolchain/$(SRC_GCC).tar.xz \
	toolchain/$(SRC_NEWLIB).tar.gz \
	toolchain/$(SRC_GDB).tar.gz \
	toolchain/$(SRC_SDCC).tar.bz2 \

download-emulator: toolchain/gngeo

download-shaders: toolchain/qcrt-glsl

toolchain/$(SRC_BINUTILS).tar.bz2:
	curl $(GNU_MIRROR)/binutils/$(notdir $@) > $@

toolchain/$(SRC_GCC).tar.xz:
	curl $(GNU_MIRROR)/gcc/$(SRC_GCC)/$(notdir $@) > $@

toolchain/$(SRC_NEWLIB).tar.gz:
	curl ftp://sourceware.org/pub/newlib/$(notdir $@) > $@

toolchain/$(SRC_GDB).tar.gz:
	curl $(GNU_MIRROR)/gdb/$(notdir $@) > $@

toolchain/$(SRC_SDCC).tar.bz2:
	curl -L http://sourceforge.net/projects/sdcc/files/sdcc/$(SRC_SDCC:sdcc-src-%=%)/$(notdir $@) > $@

toolchain/gngeo:
	@ echo downloading and setting up gngeo; \
	git clone https://github.com/dciabrin/gngeo.git $@; \
	cd $@; \
	git checkout -b ngdevkit origin/ngdevkit; \
	autoreconf -iv; \
	echo Done.

toolchain/qcrt-glsl:
	@ echo downloading example pixel shaders; \
	git clone https://github.com/dciabrin/qcrt-glsl.git $@

clean-toolchain:
	rm -f toolchain/*.tar.* toolchain/gngeo toolchain/qcrt-glsl


unpack-toolchain: \
	toolchain/$(SRC_BINUTILS) \
	toolchain/$(SRC_GCC) \
	toolchain/$(SRC_NEWLIB) \
	toolchain/$(SRC_GDB) \
	toolchain/sdcc \

toolchain/$(SRC_BINUTILS): toolchain/$(SRC_BINUTILS).tar.bz2
toolchain/$(SRC_GCC): toolchain/$(SRC_GCC).tar.xz
toolchain/$(SRC_NEWLIB): toolchain/$(SRC_NEWLIB).tar.gz
toolchain/$(SRC_GDB): toolchain/$(SRC_GDB).tar.gz
toolchain/sdcc: toolchain/$(SRC_SDCC).tar.bz2


toolchain/%:
	echo uncompressing $(notdir $@)...; \
	cd toolchain; \
	tar $(if $(filter %.gz, $<),z,$(if $(filter %.xz, $<),J,j))xmf $(notdir $<); \
	f=../patch/$(subst /,.diff,$(dir $(subst -,/,$(notdir $@)))); \
	if [ -f $$f ]; then (cd $(notdir $@); patch -p1 < ../$$f); fi; \
	echo Done.


build-compiler: build/ngbinutils build/nggcc build/ngnewlib build/ngsdcc
build-debugger: build/nggdb
build-emulator: build/gngeo
build-emulator-config: $(GNGEO_CFG)

$(GNGEO_CFG): export INPUT_SETTINGS:=$(GNGEO_DEFAULT_INPUT_SETTINGS)
$(GNGEO_CFG):
	@ echo generating a default input config for gngeo; \
	mkdir -p $(dir $(GNGEO_CFG)) && \
	echo "$$INPUT_SETTINGS" > $(GNGEO_CFG)

build/ngbinutils:
	@ echo compiling binutils...; \
	mkdir -p build/ngbinutils; \
	cd build/ngbinutils; \
	../../toolchain/$(SRC_BINUTILS)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	-v; \
	make $(HOSTOPTS); \
	make install

build/nggcc:
	@ echo compiling gcc...; \
	mkdir -p build/nggcc; \
	cd build/nggcc; \
	../../toolchain/$(SRC_GCC)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	--with-cpu=m68000 \
	--with-threads=single \
	--with-libs=$(LOCALDIR)/lib \
	--with-gnu-as \
	--with-gnu-ld \
	--with-newlib \
	--disable-multilib \
	--disable-libssp \
	--enable-languages=c \
	-v; \
	make $(HOSTOPTS); \
	make install

build/ngnewlib: build
	@ echo compiling newlib...; \
	export PATH="$(LOCALDIR)/bin:$$PATH"; \
	mkdir -p build/ngnewlib; \
	cd build/ngnewlib; \
	../../toolchain/$(SRC_NEWLIB)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	--enable-target-optspace=yes \
	--enable-newlib-multithread=no \
	-v; \
	make $(HOSTOPTS); \
	make install

build/nggdb: build
	@ echo compiling gdb...; \
	export PATH="$(LOCALDIR)/bin:$$PATH"; \
	mkdir -p build/nggdb; \
	cd build/nggdb; \
	../../toolchain/$(SRC_GDB)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	-v; \
	make $(HOSTOPTS); \
	make install

build/ngsdcc: build
	@ echo compiling sdcc...; \
	export PATH="$(LOCALDIR)/bin:$$PATH"; \
	mkdir -p build/ngsdcc; \
	cd build/ngsdcc; \
	../../toolchain/sdcc/configure \
	--prefix=$(LOCALDIR) \
	--disable-non-free \
	--enable-z80-port \
	--disable-pic14-port \
	--disable-pic16-port \
	--disable-ds390-port \
	--disable-ds400-port \
	--disable-hc08-port \
	--disable-s08-port \
	--disable-mcs51-port \
	--disable-z180-port \
	--disable-r2k-port \
	--disable-r3ka-port \
	--disable-gbz80-port \
	--disable-tlcs90-port \
	--disable-stm8-port \
	-v; \
	make $(HOSTOPTS); \
	make install

GNGEO_BUILD_FLAGS=--prefix=$(LOCALDIR) CPPFLAGS="-I$(LOCALDIR)/include" CFLAGS="-I$(LOCALDIR)/include" LDFLAGS="-L$(LOCALDIR)/lib"

build/gngeo: build
	@ echo compiling gngeo...; \
	export PATH="$(LOCALDIR)/bin:$$PATH"; \
	mkdir -p build/gngeo; \
	cd build/gngeo; \
	../../toolchain/gngeo/configure $(GNGEO_BUILD_FLAGS) && \
	make $(HOSTOPTS) && \
	make install

# (find . -name Makefile | xargs sed -i.bk -e 's/-frerun-loop-opt//g' -e 's/-funroll-loops//g' -e 's/-malign-double//g');

build-tools:
	for i in sound/nullsound nullbios runtime include tools debugger; do \
	  $(MAKE) -C $$i install; \
	done

shellinit:
	@ echo Variables set with eval $$\(make shellinit\) >&2
	@ echo export PATH="$(LOCALDIR)/bin:\$$PATH"
ifeq ($(shell uname), Darwin)
	@ echo export DYLD_LIBRARY_PATH="$(LOCALDIR)/lib:\$$DYLD_LIBRARY_PATH"
else
	@ echo export LD_LIBRARY_PATH="$(LOCALDIR)/lib:\$$LD_LIBRARY_PATH"
endif
	@ echo export PYTHONPATH="$(LOCALDIR)/bin:\$$PYTHONPATH"

clean:
	rm -rf build/ngbinutils build/nggcc build/ngnewlib
	rm -rf local/*

distclean: clean
	find toolchain -mindepth 1 -maxdepth 1 -not -name README.md -exec rm -rf {} \;
	rm -rf build local
	find . -name '*~' -exec rm -f {} \;

.PHONY: clean distclean
