#!/bin/bash -e
# Copyright (c) 2022 okibcn
# This is free software, licensed under the GNU General Public License v3.0
# See /LICENSE for more information.
# https://github.com/okibcn/nano-editor
# Description: Cross Build Mano Editor from Linux to Windows 32 and 64 bits.

# Required packages:
# sudo -E apt -qq update && sudo apt upgrade -y
# sudo -E apt -qq install -y autoconf automake autopoint gcc mingw-w64 gettext git groff make pkg-config texinfo p7zip-full

# Download sources
git clone git://git.savannah.gnu.org/nano.git
cd nano
git clone https://github.com/mirror/ncurses.git
git log -n 1
cd ncurses
git log -n 1
NCURSES=$(git show -s --format=%s)
cd ..
./autogen.sh

# >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),_MAX_PATH)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Change default terminal to nothing
sed -i 's|vt220||g' ./src/nano.c

# Fix homedir detection
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# Modify path expansion with backslashes
sed -i -e "s,free(tilded);,free(tilded);\n\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == '\\\\\\\\') \*tilded = '/';, ;
           s,path\[i\] != '/',path[i] != '/' \&\& path[i] != '\\\\\\\\'," src/files.c

# Adding static ncurses revision and patch level to nano version info.
sed -i -e "s,Compiled options,Using ${NCURSES}\\\\n Compiled options," src/nano.c
sed -i -e "s|git describe --tags 2>/dev/null|git describe --tags 2>/dev/null\` for Windows, build \`git rev-list --count HEAD|" src/Makefile.am

 ##########################
##                        ##
##    BUILD TOOLCHAIN     ##
##                        ##
 ##########################

# Build ncurses toolchain for local host 
mkdir -p build/ncurses
cd build/ncurses/
../../ncurses/configure --prefix="$(pwd)"  \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap,echo}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool} || exit 1
make -j$(($(nproc)*2)) || exit 1
cd ../..

 ##########################
##                        ##
##   BUILD FOR x86_64     ##
##                        ##
 ##########################

ARCH="x86_64"
TOOLCHAIN="${ARCH}-w64-mingw32"
OUTDIR="$(pwd)/pkg_${TOOLCHAIN}"

# cross Build ncurses for destination host 
cd build/ncurses/
export CFLAGS="-O2 -g3"
unset CPPFLAGS 
export LDFLAGS="-static-libgcc"
find . -type f  -name '*.*' | xargs rm -rf
rm Makefile -rf
../../ncurses/configure --prefix="${OUTDIR}"  \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap,echo}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  --host="${TOOLCHAIN}"  || exit 1
make -j$(($(nproc)*2)) || exit 1
make install || exit 1
cd ../..

# Build nano
mkdir -p build/nano
cd build/nano
rm * -rf
export CFLAGS="-O2 -g3 -flto"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -I\"${OUTDIR}/include\""
export LDFLAGS="-L\"${OUTDIR}/lib/\" -static -flto -static-libgcc"
export NCURSESW_CFLAGS="-I\"${OUTDIR}/include/ncursesw\" -DNCURSES_STATIC"
export NCURSESW_LIBS="-lncursesw"
../../configure --host="${TOOLCHAIN}" --prefix="${OUTDIR}"  \
  --enable-utf8 --disable-{nls,speller} \
  --sysconfdir="C:\ProgramData"  || exit 1
make -j$(($(nproc)*2)) || exit 1
make install-strip || exit 1
cd ../..

 ############################
##                          ##
## BUILD FOR i686 (32 bits) ##
##                          ##
 ############################

ARCH="i686"
TOOLCHAIN="${ARCH}-w64-mingw32"
OUTDIR="$(pwd)/pkg_${TOOLCHAIN}"

# cross Build ncurses for destination host 
cd build/ncurses/
export CFLAGS="-O2 -g3"
unset CPPFLAGS 
export LDFLAGS="-static-libgcc"
find . -type f  -name '*.*' | xargs rm -rf
rm Makefile -rf
../../ncurses/configure --prefix="${OUTDIR}"  \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap,echo}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  --host="${TOOLCHAIN}" || exit 1
make -j$(($(nproc)*2)) || exit 1
make install || exit 1
cd ../..

# Build nano
mkdir -p build/nano
cd build/nano
rm * -rf
export CFLAGS="-O2 -g3 -flto"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -I\"${OUTDIR}/include\""
export LDFLAGS="-L\"${OUTDIR}/lib/\" -static -flto -static-libgcc"
export NCURSESW_CFLAGS="-I\"${OUTDIR}/include/ncursesw\" -DNCURSES_STATIC"
export NCURSESW_LIBS="-lncursesw"
../../configure --host="${TOOLCHAIN}" --prefix="${OUTDIR}"  \
  --enable-utf8 --disable-{nls,speller} \
  --sysconfdir="C:\ProgramData"   || exit 1
make -j$(($(nproc)*2))  || exit 1
make install-strip  || exit 1
cd ../..

 ############################
##                          ##
##      CREATE PACKAGE      ##
##                          ##
 ############################

NEWTAG="$(git describe --tags 2>/dev/null | sed "s/.\{10\}$//")-$(git rev-list --count HEAD)"
strip -s pkg_{i686,x86_64}-w64-mingw32/bin/nano.exe
cp doc/sample.nanorc.in .nanorc
7z a -aoa -mmt"$(nproc)" --  \
  "nano-editor_${NANO_VERSION}.7z"  \
  pkg_{i686,x86_64}-w64-mingw32/{bin/nano.exe,share/{nano,doc}/}  \
  .nanorc  || exit 1
exit 0
