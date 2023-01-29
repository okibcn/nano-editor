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
    BUILD="$(gcc -dumpmachine)"
    TARGET="${ARCH}-w64-mingw32"
    OUTDIR="$(pwd)/pkg_${TARGET}"

    export PDCURSES_SRCDIR="$(pwd)/PDCursesMod"
    export CFLAGS="-g3 -O0 -flto -fdebug-prefix-map=`pwd`=. -I${PDCURSES_SRCDIR} -DPDC_FORCE_UTF8 -DPDCDEBUG -DPDC_NCMOUSE"
    export LDFLAGS="-L${PDCURSES_SRCDIR}/${PDTERM} -static -static-libgcc ${PDCURSES_SRCDIR}/${PDTERM}/pdcurses.a"
    export NCURSESW_CFLAGS="-I${PDCURSES_SRCDIR} -DNCURSES_STATIC  -DENABLE_MOUSE"
    export NCURSESW_LIBS="-l:pdcurses.a -lwinmm" # -lgdi32 -lcomdlg32"
    export LIBS="" #  -lshlwapi -lbcrypt"

    # cross Build pdcurses for destination host
    cd "${PDCURSES_SRCDIR}/${PDTERM}"
    make clean
    make -j$(($(nproc)*2)) WIDE=Y UTF8=Y _w${BITS}=Y DEBUG=Y demos
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

mkdir -p pnano
cd pnano
git clone git://git.savannah.gnu.org/nano.git .
git clone https://github.com/Bill-Gray/PDCursesMod.git
./autogen.sh
mkdir _srcback
cp -r src/* _srcback

 ##########################
##                        ##
##     APPLY PATCHES      ##
##                        ##
 ##########################


cp -rf ./_srcback/* ./src
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
sed -i "/Ignore this keystroke/i\\\\t\\t\\tthe_window_resized = TRUE;" src/winio.c
# sed -i "/we_are_running = TRUE/a\\\\tungetch(KEY_RESIZE);" src/nano.c

# Solve long delay after unicode 
sed -i "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d"  src/winio.c

# Solve duplicated definitions ALT-ARROWWS already in PDCursesMod
sed -i "/0x42[1234]/d" src/definitions.h

# Adding keyname to Debug hex codes (OPTIONAL)
sed -i "/fprintf.stderr, . %3x/c\
  \\\\t\\tfprintf(stderr, \" %3x-%s\", key_buffer[i], keyname(key_buffer[i])); //o//" src/winio.c
	# fprintf(stderr, "With modifiers: SHITF=%ld CTRL=%ld ALT=%ld\n", 
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_SHIFT,
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_CONTROL,
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_ALT);

# Add (Y/N/^C) to Save modified buffer prompt
sed -i "s|Save modified buffer|& (Y/N/^C)|"  src/nano.c

####
#### PDCursesMod especific patches
####

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
sed -i "/interface_color_pair/ {s/int/chtype/}" src/prototypes.h src/global.c
sed -i "/int attributes/ {s/int/chtype/}" src/definitions.h
sed -i "/bool parse_combination/ {s/int/chtype/}" src/rcfile.c
sed -i "/int attributes/ {s/int/chtype/}" src/rcfile.c

# Desambiguation of BACKSPACE vs ^H, or ENTER vs ^M and certain CTRL+key combos
sed -i "/get_kbinput(midwin, VISIBLE)/a\
    \\\\tif (!((PDC_get_key_modifiers()) & (PDC_KEY_MODIFIER_SHIFT|PDC_KEY_MODIFIER_CONTROL|PDC_KEY_MODIFIER_ALT)) ) {\\n\
    \\tswitch (input) {\\n\
    \\t\\tcase 0x08:      input = KEY_BACKSPACE; break;\\n\
    \\t\\tcase 0x0d:      input = KEY_ENTER;\\n\
    \\t}\\n\
    }\\n\
    if (PDC_get_key_modifiers() & PDC_KEY_MODIFIER_CONTROL){\\n\
    \\tswitch (input) {\\n\
    \\t\\tcase '/':          input = 31; break;\\n\
    \\t\\tcase SHIFT_DELETE: input = CONTROL_SHIFT_DELETE; break;\\n\
    \\t}\\n\
    }"  src/nano.c

# Fix for width detection using PDCursesMod internal function
sed -i 's|wcwidth(wc)|uc_width(wc, "UTF-8")|g'  src/chars.c
sed -i '/prototypes.h/a#include "uniwidth.h"'  src/chars.c

# Fix wchar_t 16 bits limitation for displaying emojis and all the suplemental codepoints:
sed -i '0,/#/s//#define wchar_t int\n&/'  src/definitions.h PDCursesMod/curses.h

# Fix browser folder change
sed -i 's/--selected/selected=0/' src/browser.c

# Fix ALT+[NUMBER|LETTER] not working with PDCursesMod
sed -i "s/char)keystring\[2])/&\+\(\(unsigned char)keystring\[2]>\='9' \? ALT_A-\(int)'a' \: ALT_0-\(int)'0')/" src/global.c


# Solve mouse detection issue when using PDCursesMod advanced mouse mode
# sed -i "/undef ENABLE_MOUSE/d"   src/definitions.h

# BRANDING and VERSIONING
LAST_FULLVERSION="$(wget -q https://api.github.com/repos/okibcn/nano-for-windows/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')" || echo "FIRST RELEASE!!!!"
LAST_VERSION="$(echo $LAST_FULLVERSION | awk -F .  '{print $1"."$2}')"  # last version without the subbuild
NANO_VERSION="$(git describe --tags 2>/dev/null | sed "s/.\{10\}$//")-$(git rev-list --count HEAD)"
NANO_DATE=$(TZ=UTC git show --quiet --date='format-local:%Y.%m.%d' --format="%cd")
if [ "${NANO_VERSION}" == "${LAST_VERSION}" ]; then
  # This is a new Windows build based on the same nano build, probably because there is a new curses patch
  SUBBUILD="$(echo $LAST_FULLVERSION | awk -F .  '{print $3}')"
  ((SUBBUILD=SUBBUILD+1))
  NANO_VERSION="${NANO_VERSION}.${SUBBUILD}"
fi
cd PDCursesMod
CURSES="$(wget -q https://api.github.com/repos/Bill-Gray/PDCursesMod/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')"
CURSES_DATE=$(TZ=UTC git show --quiet --date='format-local:%Y.%m.%d' --format="%cd")
CURSES="PDCursesMod ${CURSES} build $(git rev-list --count HEAD), ${CURSES_DATE}"
cd ..

sed -i 's/ GNU nano from git,//' src/nano.c
sed -i 's|Compiled options|Using '"${CURSES}"'\\n &|' src/nano.c
sed -i '/SOMETHING = "REVISION/cSOMETHING = "REVISION \\"GNU nano for Windows, '"${NANO_VERSION}"' 64 bits, '"${NANO_DATE}"'\\""' src/Makefile.am
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
