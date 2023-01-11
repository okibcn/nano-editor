#!/bin/bash -e

## NANO build script in Ubuntu

sudo -E apt update && sudo apt upgrade -y
sudo -E apt install -y autoconf automake autopoint gcc gettext git groff make pkg-config texinfo


git clone git://git.savannah.gnu.org/nano.git nano
cd nano
wget -c "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz"
tar -xzvf ncurses-6.4.tar.gz
PKG=$(pwd)/pkg
host="${1:-x86_64}-linux-gnu"
# host="${1:-x86_64}-w64-mingw32"
mkdir -p build/ncurses
mkdir -p build/nano

cd build/ncurses/
../../ncurses-6.4/configure --prefix="${PKG}"  --host="${host}" --enable-widec --without-ada  --without-manpages \
    --without-debug  --enable-static  --without-tests
#   --without-ada --without-cxx-binding --disable-db-install --without-manpages  \
#   --without-pthread --without-debug --enable-widec --disable-database  \
#   --disable-rpath --enable-termcap --disable-home-terminfo --enable-sp-funcs  \
#   --enable-term-driver --enable-static --disable-shared --without-tests # --host="${_host}" 
make -j$(nproc)
make install
cd ../..

./autogen.sh
cd build/nano
export CURSES_LIB_NAME="ncursesw"
export CURSES_LIB="-lncursesw"
export LDFLAGS="-O2 -L\"${PKG}/lib/\" -static"
export CPPFLAGS="-DHAVE_NCURSESW_NCURSES_H -DNCURSES_STATIC  \
                 -I\"${PKG}/include\" -I\"${PKG}/include/ncursesw\""
# touch roll-a-release.sh  # Lie to configure.ac to make use of `git describe`.
../../configure --prefix="${PKG}"   --host="${host}" --disable-utf8 
--enable-nanorc --enable-color --disable-utf8 --disable-nls --disable-speller  \
  --disable-threads --disable-rpath # --sysconfdir="${ALLUSERSPROFILE}" --host="${_host}" 
make -j$(nproc)
make install-strip
