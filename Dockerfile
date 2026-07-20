FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt install -y autoconf autoconf-archive automake gcc curl zip unzip \
libsdl2-dev python3-pygame libreadline-dev git
# make sure you have src packages enabled for dependency information
RUN echo "deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted" > /etc/apt/sources.list.d/ngdevkit.list
RUN echo "deb-src http://archive.ubuntu.com/ubuntu/ focal universe" >> /etc/apt/sources.list.d/ngdevkit.list
RUN apt update -y
# install build-dependency packages
RUN export GCC_VERSION_PKG=`apt-cache depends gcc | awk '/Depends.*gcc/ {print $2}'` \
&& echo "GCC_VERSION_PKG=$GCC_VERSION_PKG" \
&& apt build-dep -y $GCC_VERSION_PKG \
&& apt build-dep -y --arch-only sdcc
# optional: install GLEW for OpenGL+GLSL shaders in GnGeo
RUN apt install -y libglew-dev
# dependencies for the example ROMs
RUN apt install -y imagemagick sox libsox-fmt-mp3

## Building the toolchain
WORKDIR /ngdevkit
COPY . .
RUN autoreconf -iv \
&& ./configure --prefix=$PWD/local \
&& make \
&& make install

# ngdevkit-gngeo
RUN make shellinit >> ~/.bashrc