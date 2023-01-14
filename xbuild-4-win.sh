#!/bin/bash

# Copyright (c) 2022 okibcn
# This is free software, licensed under the GNU General Public License v3.0
# See /LICENSE for more information.
# https://github.com/okibcn/nano-editor
# Description: Cross Build Mano Editor from Linux to Windows 32 and 64 bits.

# Required packages:
# sudo -E apt -qq update && sudo apt upgrade -y
# sudo -E apt -qq install -y autoconf automake autopoint gcc mingw-w64 gettext git groff make pkg-config texinfo p7zip-full


 ##########################
##                        ##
##    DOWNLOAD SOURCES    ##
##                        ##
 ##########################
git clone git://git.savannah.gnu.org/nano.git
cd nano
git clone https://github.com/mirror/ncurses.git
git log -n 1
cd ncurses
git log -n 1
NCURSES=$(git show -s --format=%s)
cd ..
./autogen.sh

 ##########################
##                        ##
##     APPLY PATCHES      ##
##                        ##
 ##########################

# >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#include <windows.h>"  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Change default terminal to nothing
sed -i 's|vt220||g' ./src/nano.c

# Fix homedir detection
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# Modify path expansion with backslashes
sed -i -e "s,free(tilded);,free(tilded);\n\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == '\\\\\\\\') \*tilded = '/';, ;
           s,path\[i\] != '/',path[i] != '/' \&\& path[i] != '\\\\\\\\'," src/files.c

# Modify temporal path from linux to windows
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

# Solve SHIFT, ALT and CTRL keys
sed -i "s,waiting_codes = 1;,waiting_codes = 0;\n\
    if (GetAsyncKeyState(VK_LMENU) < 0)	key_buffer[waiting_codes++] = ESC_CODE;\n\
    key_buffer[waiting_codes++] = input;," src/winio.c
sed -i '/TIOCLINUX/c \\tmodifiers \= 0; \
    if(GetAsyncKeyState(VK_SHIFT) < 0) modifiers |\= 0x01; \
    if(GetAsyncKeyState(VK_CONTROL) < 0) modifiers |\= 0x04; \
    if(GetAsyncKeyState(VK_LMENU) < 0) modifiers |\= 0x08; \
    if (!mute_modifiers) {' src/winio.c

# default open() files in binary mode as it does in linux
sed -i 's/ONLY/ONLY | _O_BINARY/g' ./src/files.c
sed -i 's/ONLY/ONLY | _O_BINARY/g' ./src/text.c

# Adding static ncurses revision and patch level to nano version info.
sed -i -e "s,Compiled options,Using ${NCURSES}\\\\n Compiled options," src/nano.c
sed -i -e "s|git describe --tags 2>/dev/null|git describe --tags 2>/dev/null\` for Windows, build \`git rev-list --count HEAD|" src/Makefile.am

 ##########################
##                        ##
##   BUILD FOR x86_64     ##
##                        ##
 ##########################

ARCH="x86_64"

TARGET="${ARCH}-w64-mingw32"
OUTDIR="$(pwd)/pkg_${TARGET}"

export CFLAGS="-O2 -g3"
unset CPPFLAGS 
export LDFLAGS="-static-libgcc"

# cross Build ncurses for destination host 
mkdir -p "$(pwd)/build_${TARGET}/ncurses"
cd "$(pwd)/build_${TARGET}/ncurses"
rm -rf *
../../ncurses/configure --prefix="${OUTDIR}"  \
  --enable-{widec,sp-funcs,termcap,exp-win32,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap,echo}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  \
  --build="$(gcc -dumpmachine)" --host="${TARGET}" || exit 1
make -j$(($(nproc)*2)) && make install || exit 1
cd ../..

# Build nano
mkdir -p "$(pwd)/build_${TARGET}/nano"
cd "$(pwd)/build_${TARGET}/nano"
rm -rf *
export CFLAGS="-O2 -g3 -flto"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -I\"${OUTDIR}/include\""
export LDFLAGS="-L\"${OUTDIR}/lib/\" -static -flto -static-libgcc"
export NCURSESW_CFLAGS="-I\"${OUTDIR}/include/ncursesw\" -DNCURSES_STATIC"
export NCURSESW_LIBS="-lncursesw"
export LIBS="-lshlwapi" # -lbcrypt"
../../configure --host="${TARGET}" --prefix="${OUTDIR}"  \
  --enable-utf8 --disable-{nls,speller} \
  --sysconfdir="C:\ProgramData"  # || exit 1
make -j$(($(nproc)*2)) && make install-strip # || exit 1
cd ../..

 ############################
##                          ##
## BUILD FOR i686 (32 bits) ##
##                          ##
 ############################

ARCH="i686"

TARGET="${ARCH}-w64-mingw32"
OUTDIR="$(pwd)/pkg_${TARGET}"

export CFLAGS="-O2 -g3"
unset CPPFLAGS 
export LDFLAGS="-static-libgcc"

# cross Build ncurses for destination host 
mkdir -p "$(pwd)/build_${TARGET}/ncurses"
cd "$(pwd)/build_${TARGET}/ncurses"
rm -rf *
../../ncurses/configure --prefix="${OUTDIR}" \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap,echo}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  \
  --build="$(gcc -dumpmachine)" --host="${TARGET}" || exit 1
make -j$(($(nproc)*2)) && make install || exit 1
cd ../..

# Build nano
mkdir -p "$(pwd)/build_${TARGET}/nano"
cd "$(pwd)/build_${TARGET}/nano"
rm -rf *
export CFLAGS="-O2 -g3 -flto"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -I\"${OUTDIR}/include\""
export LDFLAGS="-L\"${OUTDIR}/lib/\" -static -flto -static-libgcc"
export NCURSESW_CFLAGS="-I\"${OUTDIR}/include/ncursesw\" -DNCURSES_STATIC"
export NCURSESW_LIBS="-lncursesw"
# export LIBS="-lshlwapi -lbcrypt"
../../configure --host="${TARGET}" --prefix="${OUTDIR}"  \
  --enable-utf8 --disable-{nls,speller} \
  --sysconfdir="C:\ProgramData"  || exit 1
make -j$(($(nproc)*2)) && make install-strip || exit 1
cd ../..


 ############################
##                          ##
##      CREATE PACKAGE      ##
##                          ##
 ############################

NANO_VERSION="$(git describe --tags 2>/dev/null | sed "s/.\{10\}$//")-$(git rev-list --count HEAD)"
strip -s pkg_{i686,x86_64}-w64-mingw32/bin/nano.exe
cp doc/sample.nanorc.in .nanorc
7z a -aoa -mmt"$(nproc)" --  \
  "nano-editor_${NANO_VERSION}.7z"  \
  pkg_{i686,x86_64}-w64-mingw32/{bin/nano.exe,share/{nano,doc}/}  \
  .nanorc  || exit 1
exit 0
