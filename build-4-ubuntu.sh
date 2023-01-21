#!/bin/bash -e

## NANO build script in Ubuntu

sudo -E apt update && sudo apt upgrade -y
sudo -E apt install -y autoconf automake autopoint gcc gettext git groff make pkg-config texinfo p7zip


git clone git://git.savannah.gnu.org/nano.git nano
cd nano
wget -c "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz"
tar -xzvf ncurses-6.4.tar.gz
./autogen.sh

PKG=$(pwd)/pkg
host="${1:-x86_64}-linux-gnu"
# host="${1:-x86_64}-w64-mingw32"
mkdir -p build/ncurses
mkdir -p build/nano

cd build/ncurses/
../../ncurses-6.4/configure --prefix="${PKG}"  --host="${host}" --enable-widec --without-ada  --without-manpages \
    --without-debug  --enable-static  --without-tests

make -j$(nproc)
make install
cd ../..


cd build/nano
export CURSES_LIB_NAME="ncursesw"
export CURSES_LIB="-lncursesw"
export LDFLAGS="-O2 -g3 -static"
export CPPFLAGS="-DHAVE_NCURSESW_NCURSES_H -DNCURSES_STATIC  \
                 -I\"${PKG}/include\" -I\"${PKG}/include/ncursesw\""
touch roll-a-release.sh  # Lie to configure.ac to make use of `git describe`.
../../configure --prefix="${PKG}"   --host="${host}" \
  --enable-utf8 --disable-{nls,speller,libmagic}
make -j$(nproc)
make install-strip
