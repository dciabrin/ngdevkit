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

# Install dir, GNU mirrors...
include Makefile.config

SRC_BINUTILS=binutils-2.25
SRC_GCC=gcc-4.9.2
SRC_NEWLIB=newlib-1.14.0

all: \
	download-toolchain \
	unpack-toolchain \
	build-compiler \
	build-tools

download-toolchain: \
	toolchain/$(SRC_BINUTILS).tar.bz2 \
	toolchain/$(SRC_GCC).tar.bz2 \
	toolchain/$(SRC_NEWLIB).tar.gz

toolchain/$(SRC_BINUTILS).tar.bz2: toolchain
	curl $(GNU_MIRROR)/binutils/$(notdir $@) -o $@

toolchain/$(SRC_GCC).tar.bz2: toolchain
	curl $(GNU_MIRROR)/gcc/$(SRC_GCC)/$(notdir $@) -o $@

toolchain/$(SRC_NEWLIB).tar.gz: toolchain
	curl ftp://sourceware.org/pub/newlib/$(notdir $@) -o $@

clean-toolchain:
	rm -f toolchain/*.tar.*


unpack-toolchain: \
	toolchain/$(SRC_BINUTILS) \
	toolchain/$(SRC_GCC) \
	toolchain/$(SRC_NEWLIB)

toolchain/$(SRC_BINUTILS): toolchain/$(SRC_BINUTILS).tar.bz2
toolchain/$(SRC_GCC): toolchain/$(SRC_GCC).tar.bz2
toolchain/$(SRC_NEWLIB): toolchain/$(SRC_NEWLIB).tar.gz


toolchain/%: 
	echo uncompressing $(notdir $@)...; \
	cd toolchain; \
	tar $(if $(filter %.gz, $<),z,j)xmf $(notdir $<); \
	f=../patch/$(subst /,.diff,$(dir $(subst -,/,$(notdir $@)))); \
	if [ -f $$f ]; then (cd $(notdir $@); patch -p1 < ../$$f); fi; \
	echo Done.


build-compiler: build/ngbinutils build/nggcc build/ngnewlib

build/ngbinutils: build
	@ echo compiling binutils...; \
	mkdir build/ngbinutils; \
	cd build/ngbinutils; \
	../../toolchain/$(SRC_BINUTILS)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	-v; \
	make $(HOSTOPTS); \
	make install

build/nggcc: build
	@ echo compiling gcc...; \
	mkdir build/nggcc; \
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
	export PATH=$(LOCALDIR)/bin:$$PATH; \
	mkdir build/ngnewlib; \
	cd build/ngnewlib; \
	../../toolchain/$(SRC_NEWLIB)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	--enable-target-optspace=yes \
	--enable-newlib-multithread=no \
	-v; \
	make $(HOSTOPTS); \
	make install


build-tools:
	for i in nullbios runtime include tools/tiletool; do \
	  $(MAKE) -s -C $$i install; \
	done

build toolchain:
	mkdir $@

clean:
	rm -rf build/ngbinutils build/nggcc build/ngnewlib
	rm -rf local/*

clean-all: clean
	rm -rf toolchain build
	find . -name '*~' -exec rm -f {} \;

.PHONY: clean clean-all
