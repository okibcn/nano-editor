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
    # cd ~/nano
    ARCH="${1:-x86_64}"
    PDTERM="${2:-wincon}"    # PDCursesMod supports wincon, vt, wingui, sdl1, sdl2
    [ "${ARCH}" = "x86_64" ] && BITS="64" || BITS="32"
    BUILD="$(gcc -dumpmachine)"
    TARGET="${ARCH}-w64-mingw32"
    OUTDIR="$(pwd)/pkg_${TARGET}"
    export PDCURSES_SRCDIR="$(pwd)/PDCursesMod"

    export CFLAGS="-g -O0 -flto -fdebug-prefix-map=`pwd`=. -I${PDCURSES_SRCDIR} -DPDC_FORCE_UTF8 -DPDCDEBUG -DPDC_NCMOUSE"
    export LDFLAGS="-L${PDCURSES_SRCDIR}/${PDTERM} -static -static-libgcc ${PDCURSES_SRCDIR}/${PDTERM}/pdcurses.a"
    export NCURSESW_CFLAGS="-I${PDCURSES_SRCDIR} -DNCURSES_STATIC  -DENABLE_MOUSE"
    export NCURSESW_LIBS="-l:pdcurses.a -lwinmm" # -lgdi32 -lcomdlg32"
    export LIBS="" #  -lshlwapi -lbcrypt"

    # cross Build pdcurses for destination host
    cd "${PDCURSES_SRCDIR}/${PDTERM}"
    make clean
    make -j$(($(nproc)*2)) WIDE=Y UTF8=Y _w${BITS}=Y demos
    cd ../..

    # Build nano
    sed -i 's/Windows.*/Windows '"${BITS}"' bits\\""/' src/Makefile.am
    mkdir -p "$(pwd)/build_${TARGET}/nano"
    cd "$(pwd)/build_${TARGET}/nano"
    rm -rf *
    ../../configure --host="${TARGET}" --prefix="${OUTDIR}"  \
      --enable-{utf8,threads=windows,debug} --disable-{nls,speller} \
      --sysconfdir="C:\\ProgramData" && \
    make -j$(($(nproc)*2)) && \
    make install-strip  && \
    echo "RESULT:  Successfully build GNU Nano $(git describe|rev|cut -c11-|rev) build $(git rev-list --count HEAD) for Windows $BITS bits" || \
    echo "RESULT:  ****  BUILD FAILED ****"
    cd ../..
    cp -f ${OUTDIR}/bin/nano.exe ~/desktop
    cp -f "${PDCURSES_SRCDIR}/${PDTERM}/"*.exe ~/desktop/demos
  

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

# 1. >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
# 2. Adding windows.h for supporting keypress detection.
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
# echo "#include <windows.h>"  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Modify temporal path from linux to windows
sed -i 's|TMPDIR|TEMP|g' ./src/files.c

# Change default terminal to nothing to remove terminal limitations.
sed -i 's|vt220||g

  /nl_langinfo(CODESET)/ c\\tsetlocale(LC_ALL, "");'  src/nano.c

nl_langinfo(CODESET)

# Fix homedir detection
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# Modify path expansion with backslashes
sed -i "/free(tilded)/a\
  \\\\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == '\\\\\\\\') \*tilded = '/';

  s|path\[i\] != '/'|path[i] != '/' \&\& path[i] != '\\\\\\\\'|" src/files.c

# default open() files in binary mode as linux
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
sed -i 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c

# Allow custom colors in terminals with more than 256 colors
sed -i "/COLORS == 256/ {s/==/>=/}"  src/rcfile.c

# Solve windows resize crashes
sed -i -e "/LINES and COLS accordingly/{n;N;d}" src/nano.c # delets 2 next lines
sed -i "/LINES and COLS accordingly/a\
    \\\\tresize_term(0, 0); \\n\
    erase();" src/nano.c
sed -i -e "/recreate the subwindows with their (new) sizes/{n;d}" src/nano.c
sed -i "/we_are_running = TRUE/a\\\\tthe_window_resized = TRUE;" src/nano.c
sed -i "/Ignore this keystroke/i\\\\t\\t\\tthe_window_resized = TRUE;" src/winio.c

# Solve long delay after unicode 
# sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d"  src/winio.c

# Solve duplicated definitions ALT-ARROWWS already in PDCursesMod
sed -i "/0x42[1234]/d" src/definitions.h

# Adding static PDCurses revision and patch level to nano version info.
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
CURSES="$(wget -q https://api.github.com/repos/Bill-Gray/PDCursesMod/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')"
CURSES="PDCursesMod ${CURSES} build $(git rev-list --count HEAD)"
cd ..

sed -i 's|Compiled options|Using '"${CURSES}"'\\n &|' src/nano.c
sed -i '/SOMETHING = "REVISION/cSOMETHING = "REVISION \\"'"${NANO_VERSION}"' for Windows\\""' src/Makefile.am
echo -e "GNU nano version Tag: ${NANO_VERSION}\nUsing $CURSES"

# Debug hex codes (OPTIONAL)
sed -i "/fprintf.stderr, . %3x/c\
  \\\\t\\tfprintf(stderr, \" %3x-%s\", key_buffer[i], keyname(key_buffer[i])); //o//" ~/nano/src/winio.c

# Add (Y/N/^C) to Save modified buffer prompt
sed -i "s|Save modified buffer|& (Y/N/^C)|"  src/nano.c

#### PDCursesMod especific patches

# PDCurses uses 64bit color type chtype instead of 32bit int
sed -i "/interface_color_pair/ {s/int/chtype/}"  src/prototypes.h
sed -i "/interface_color_pair/ {s/int/chtype/}"  src/global.c

# Desambiguation of BACKSPACE vs ^H, or ENTER vs ^M
sed -i "/get_kbinput(midwin, VISIBLE)/a\
    \\\\tif (!((PDC_get_key_modifiers()) & (PDC_KEY_MODIFIER_SHIFT|PDC_KEY_MODIFIER_CONTROL|PDC_KEY_MODIFIER_ALT)) ) {\\n\
    \\t\\tswitch (input) {\\n\
		\\t\\t\\tcase 0x08:      input = KEY_BACKSPACE; break;\\n\
		\\t\\t\\tcase 0x0d:      input = KEY_ENTER;\\n\
		\\t\\t}\\n\
	  \\t}"  src/nano.c

# Solve mouse detection issue when using PDCursesMod advanced mouse mode
# sed -i "/undef ENABLE_MOUSE/d"   src/definitions.h

# Solve SHIFT, ALT and CTRL keys
# sed -i 's/waiting_codes = 1;/waiting_codes = 0;\
#     if (GetAsyncKeyState(VK_LMENU) < 0)	key_buffer[waiting_codes++] = ESC_CODE;\
#     key_buffer[waiting_codes++] = input;/

#     /TIOCLINUX/c \\tmodifiers \= 0;\
#     if(GetAsyncKeyState(VK_SHIFT) < 0) modifiers |\= 0x01;\
#     if(GetAsyncKeyState(VK_CONTROL) < 0) modifiers |\= 0x04;\
#     if(GetAsyncKeyState(VK_LMENU) < 0) modifiers |\= 0x08;\
#     if \(\!mute_modifiers) \{' src/winio.c
# sed  -i '/parse_kbinput/!b
#     :a
#     s/__linux__/_WIN32/;t trail
#     n;ba
#     :trail
#     n;btrail' src/winio.c



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
