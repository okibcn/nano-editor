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
##  BUILD FOR x86_64|i686 ##
##                        ##
 ##########################
build () {
    ARCH="${1:-x86_64}"
    PDTERM="${2:-wincon}"    # PDCursesMod supports wincon, vt, wingui, sdl1, sdl2
    [ "${ARCH}" = "x86_64" ] && BITS="64" || BITS="32"
    BUILD="$(gcc -dumpmachine)"
    TARGET="${ARCH}-w64-mingw32"
    OUTDIR="$(pwd)/pkg_${TARGET}"
    export PDCURSES_SRCDIR="$(pwd)/PDCursesMod"

    export CFLAGS="-I${PDCURSES_SRCDIR} -DPDC_FORCE_UTF8"
    export LDFLAGS="-L${PDCURSES_SRCDIR}/${PDTERM} -static -static-libgcc ${PDCURSES_SRCDIR}/${PDTERM}/pdcurses.a"
    export NCURSESW_CFLAGS="-I${PDCURSES_SRCDIR} -DNCURSES_STATIC"
    export NCURSESW_LIBS="-lpdcurses -lwinmm -lshlwapi"
    export LIBS="" # -lbcrypt"

    # cross Build ncurses for destination host 
    cd "${PDCURSES_SRCDIR}/${PDTERM}"
    make clean
    make -j$(($(nproc)*2)) WIDE=Y UTF8=Y _w${BITS}=Y
    cp pdcurses.a libncursesw.a
    cp pdcurses.a libpdcurses.a
    cd ../..

    # Build nano
    sed -i 's/Windows.*/Windows '"${BITS}"' bits\\""/' src/Makefile.am
    mkdir -p "$(pwd)/build_${TARGET}/nano"
    cd "$(pwd)/build_${TARGET}/nano"
    rm -rf *
    ../../configure --host="${TARGET}" --prefix="${OUTDIR}"  \
      --enable-{utf8,threads=windows} --disable-{nls,speller} \
      --sysconfdir="C:\\ProgramData"  # || exit 1
    make -j$(($(nproc)*2)) && make install-strip # || exit 1
    cd ../..
    cp -f ${OUTDIR}/bin/nano.exe ~/desktop
    echo "Successfully build GNU Nano $(git describe|rev|cut -c11-|rev) build $(git rev-list --count HEAD) for Windows $BITS bits"
}

 ##########################
##                        ##
##    DOWNLOAD SOURCES    ##
##                        ##
 ##########################

git clone git://git.savannah.gnu.org/nano.git
cd nano
git clone https://github.com/Bill-Gray/PDCursesMod.git
./autogen.sh

 ##########################
##                        ##
##     APPLY PATCHES      ##
##                        ##
 ##########################

# >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
# 1. >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
# 2. Adding windows.h for supporting keypress detection.
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#include <windows.h>"  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Change default terminal to nothing
sed -i 's|vt220||g' ./src/nano.c

# Fix homedir detection
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# Modify temporal path from linux to windows
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

# Modify path expansion with backslashes
sed -i "/free(tilded)/a\
  \\\\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == '\\\\\\\\') \*tilded = '/';

  s|path\[i\] != '/'|path[i] != '/' \&\& path[i] != '\\\\\\\\'|" src/files.c

# Solve SHIFT, ALT and CTRL keys
sed -i 's/waiting_codes = 1;/waiting_codes = 0;\
    if (GetAsyncKeyState(VK_LMENU) < 0)	key_buffer[waiting_codes++] = ESC_CODE;\
    key_buffer[waiting_codes++] = input;/

    /TIOCLINUX/c \\tmodifiers \= 0;\
    if(GetAsyncKeyState(VK_SHIFT) < 0) modifiers |\= 0x01;\
    if(GetAsyncKeyState(VK_CONTROL) < 0) modifiers |\= 0x04;\
    if(GetAsyncKeyState(VK_LMENU) < 0) modifiers |\= 0x08;\
    if \(\!mute_modifiers) \{' src/winio.c
sed  -i '/parse_kbinput/!b
    :a
    s/__linux__/_WIN32/;t trail
    n;ba
    :trail
    n;btrail' src/winio.c

# default open() files in binary mode as it does in linux
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Adding static ncurses revision and patch level to nano version info.
LAST_VERSION="$(wget -q https://api.github.com/repos/okibcn/nano-editor/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')" \
  || echo "FIRST RELEASE!!!!"
NANO_VERSION="$(git describe --tags 2>/dev/null | sed "s/.\{10\}$//")-$(git rev-list --count HEAD)"
LAST_BASEVERSION="$(echo $LAST_VERSION | awk -F .  '{print $1"."$2}')"  # last version without the subbuild
if [ "${NANO_VERSION}" == "${LAST_BASEVERSION}" ]; then
  # This is a new Windows build based on the same nano build, probably because there is a new ncurses patch
  SUBBUILD="$(echo $LAST_VERSION | awk -F .  '{print $3}')"
  ((SUBBUILD=SUBBUILD+1))
  NANO_VERSION="${NANO_VERSION}.${SUBBUILD}"
fi
cd PDCursesMod
CURSES="$(wget -q https://api.github.com/repos/Bill-Gray/PDCursesMod/releases/latest -O - |
awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')"
CURSES="PDCursesMod ${CURSES} build $(git rev-list --count HEAD)"
cd ..

sed -i 's|Compiled options|Using '"${CURSES}"'\\n &|' src/nano.c
sed -i '/SOMETHING = "REVISION/cSOMETHING = "REVISION \\"'"${NANO_VERSION}"' for Windows\\""' src/Makefile.am
echo -e "GNU nano version Tag: ${NANO_VERSION}\nUsing $CURSES"
# echo "NANO_VERSION=${NANO_VERSION}" >>$GITHUB_ENV

 ############################
##                          ##
## BUILD for 64 and 32 bits ##
##                          ##
 ############################
build x86_64
build i686

 ############################
##                          ##
##      CREATE PACKAGE      ##
##                          ##
 ############################

strip -s pkg_{i686,x86_64}-w64-mingw32/bin/nano.exe
cp doc/sample.nanorc.in .nanorc
7z a -aoa -mmt"$(nproc)" --  \
  "nano-editor_${NANO_VERSION}.7z"  \
  pkg_{i686,x86_64}-w64-mingw32/{bin/nano.exe,share/{nano,doc}/}  \
  .nanorc  || exit 1
exit 0
