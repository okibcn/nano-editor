#!/bin/bash -e

pacman -S --noconfirm "${MINGW_PACKAGE_PREFIX}-autotools" patch texinfo pkg-config
git clone git://git.savannah.gnu.org/nano.git nano
cd nano
./autogen.sh

_host="${1:-x86_64}-w64-mingw32"
_pwd="$(cygpath -m $(pwd) || readlink -f $(pwd))"
_nproc="$(nproc)"
_prefix="${_pwd}/pkg_${_host}"
export LIBS="-lshlwapi -lbcrypt"
export PKG_CONFIG="true"  # Force it to succeed.
export CURSES_LIB_NAME="ncursesw"
export CURSES_LIB="-lncursesw"
export CFLAGS="-O2 -g3"
export LDFLAGS="-O2 -L\"${_prefix}/lib/\" -static"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -DHAVE_NCURSESW_NCURSES_H -DNCURSES_STATIC  \
                 -I\"${_prefix}/include\" -I\"${_prefix}/include/ncursesw\""

wget -c "https://invisible-mirror.net/archives/ncurses/ncurses-6.3.tar.gz"
tar -xzvf ncurses-6.3.tar.gz
patch -p1 < ../ncurses-6.3.patch

# realpath doesn't exist on Windows, which isn't fully POSIX compliant.
echo " " >> ./src/prototypes.h
echo "#ifdef _WIN32" >> ./src/prototypes.h
echo "#include <stdlib.h>" >> ./src/prototypes.h
echo "#define realpath(N,R) _fullpath((R),(N),_MAX_PATH)" >> ./src/prototypes.h
echo "#endif" >> ./src/prototypes.h

# use windows environment variables for filesystem
patch ./src/utils.c ../utils.c.patch

mkdir -p "${_pwd}/build_${_host}"
pushd "${_pwd}/build_${_host}"

mkdir -p "ncurses"
pushd "ncurses"
../../ncurses-6.3/configure --host="${_host}" --prefix="${_prefix}"  \
  --without-ada --without-cxx-binding --disable-db-install --without-manpages  \
  --without-pthread --without-debug --enable-widec --disable-database  \
  --disable-rpath --enable-termcap --disable-home-terminfo --enable-sp-funcs  \
  --enable-term-driver --enable-static --disable-shared --without-tests
make -j"${_nproc}"
make install
popd

mkdir -p "nano"
pushd "nano"
touch roll-a-release.sh  # Lie to configure.ac to make use of `git describe`.
../../configure --host="${_host}" --prefix="${_prefix}" --enable-nanorc  \
  --enable-color --disable-utf8 --disable-nls --disable-speller  \
  --disable-threads --disable-rpath --sysconfdir="${ALLUSERSPROFILE}"
make -j"${_nproc}"
make install-strip
popd
