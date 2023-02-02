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

mkdir -p nano
cd nano
git clone git://git.savannah.gnu.org/nano.git .
git clone https://github.com/Bill-Gray/PDCursesMod.git curses
./autogen.sh
mkdir _srcback
cp -r src/* _srcback

 ##########################
##                        ##
##     APPLY PATCHES      ##
##                        ##
 ##########################
function _diff() {
  # Thanks to @rasa for this function
  bak=$(find . -type f -name '*.bak' | head -n 1)
  test -z "${bak}" && return
  src=${bak/.bak/}
  n=1
  while : ; do
    patch=${src}-${n}.patch
    test -f "${patch}" || break
    ((n++))
  done
  diff -u -w "${bak}" "${src}" >"${patch}" || true
  rm -f "${bak}" || true
  if [[ ! -s "${patch}" ]]; then
    rm -f "${patch}" || true
    return 0
  fi
  echo "${patch}":
  cat "${patch}"
  return 0
}

cp -rf ./_srcback/* ./src
# 1. >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
echo -e "\n\nPATCH: realpath() workaround applied."
cp -p ./src/definitions.h{,.bak}
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
# echo "#include <windows.h>"  >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),0)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h
_diff

# Fix homedir detection
echo -e "\n\nPATCH: configuring Windows home folder."
sed -i.bak 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c
_diff

# Modify temporal path from linux to windows
echo -e "\n\nPATCH: configuring Windows temporal folder."
sed -i.bak 's|TMPDIR|TEMP|g' ./src/files.c
echo -e "\n\nPATCH: Convert invalid filename characters to ! for backup files."
sed -i "s~if (thename\[i\] == '/')~if (strchr(\"<>:\\\\\"/\\\\\\\\|?*\", thename[i]))~g" ./src/files.c
sed -i 's|/tmp/|~/AppData/Local/Temp/|g' ./src/files.c
_diff

# Modify path expansion with backslashes
echo -e "\n\nPATCH: Configuring backslashes for folders."
sed -i.bak "/free(tilded)/a\
  \\\\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == '\\\\\\\\') \*tilded = '/';

  s|path\[i\] != '/'|path[i] != '/' \&\& path[i] != '\\\\\\\\'|" src/files.c
_diff

# default open() files in binary mode as linux does
echo -e "\n\nPATCH: Forcing file management in binary mode like the Linux version."
sed -i.bak 's/O_..ONLY/& | _O_BINARY/g' ./src/files.c
_diff
sed -i.bak 's/O_..ONLY/& | _O_BINARY/g' ./src/text.c
_diff

# Enable UTF-8 Terminal
echo -e "\n\nPATCH: Enable UTF-8 console."
sed -i.bak 's|vt220||g
  /x1B/d
  /nl_langinfo(CODESET)/ c\\tsetlocale(LC_ALL, "");'  src/nano.c
_diff

# Allow custom colors in terminals with more than 256 colors
echo -e "\n\nPATCH: Allow true color."
sed -i.bak "/COLORS == 256/ {s/==/>=/}"  src/rcfile.c
_diff

# Solve window resize crashes
echo -e "\n\nPATCH: Window resize fix."
sed -i.bak -e "/LINES and COLS accordingly/{n;N;d}" src/nano.c # delets 2 next lines
sed -i "/LINES and COLS accordingly/a\
    \\\\tresize_term(0, 0); \\n\
    erase();" src/nano.c
sed -i -e "/recreate the subwindows with their (new) sizes/{n;d}" src/nano.c
_diff
sed -i.bak 's/the_window_resized/input == KEY_RESIZE/' src/winio.c
_diff

# Solve long delay after unicode 
echo -e "\n\nPATCH: solved deadlock with unicode characters."
sed -i.bak "/halfdelay(ISSET(QUICK_BLANK)/,/disable_kb_interrupt/d"  src/winio.c
_diff

# Add (Y/N/^C) to Save modified buffer prompt
echo -e "\n\nPATCH: More info for exit message."
sed -i.bak "s|Save modified buffer|& (Y/N/^C)|"  src/nano.c
_diff

# Fix browser folder change
echo -e "\n\nPATCH: Fixed browser folder change."
sed -i.bak 's/--selected/selected=0/' src/browser.c
_diff

# Fix for unicode char width detection using GNUlib internal function
echo -e "\n\nPATCH: unicode char width detection using GNUlib internal function."
sed -i.bak 's|wcwidth(wc)|uc_width(wc, "UTF-8")|g'  src/chars.c
sed -i '/prototypes.h/a#include "uniwidth.h"'  src/chars.c
_diff

# Fix pipe-in data from Windows console.
echo -e "\n\nPATCH: Fix pipe in data in Windows console."
sed -i.bak "s/stream, 0/stream, fd/" src/nano.c
sed -i "s|/dev/tty|CON|" src/nano.c
sed -i "/FILE \*stream/,/stop the reading/ c\
  \\\\t static FILE \*stream;\\n\
  static int fd\=0;\\n\
  if \(fd\=\=0){\\n\
  if \(GetConsoleWindow\() \!\= NULL)\\n\
    fprintf\(stderr, _\(\"Reading data from keyboard; type a ^Z line to finish.\\\\n\"));\\n\
  fd \= dup\(0);\\n\
  stream \= fdopen\(fd, \"rb\");\\n\
  freopen\(\"CON\", \"rb\", stdin);\\n\
  FreeConsole\();\\n\
  AttachConsole\(ATTACH_PARENT_PROCESS);\\n\
  return FALSE;}\\n\
  endwin\();\\n\
  if \(stream \=\= NULL) {\\n\
  \\t int errnumber \= errno;\\n\
  \\t if\(fd \> -1) close\(fd);\\n\
  return FALSE;}" src/nano.c
sed -i "/initscr/i\
  for\(int optind_\=optind; optind_ \< argc;optind_\+\+)\\n\
    if \(strcmp\(argv\[optind_], \"\-\") \=\= 0){scoop_stdin\();break;}\\n\" src/nano.c
_diff
  
# Adding keyname to Debug hex codes (OPTIONAL)
sed -i "/fprintf.stderr, . %3x/c\
  \\\\t\\tfprintf(stderr, \" %3x-%s\", key_buffer[i], keyname(key_buffer[i])); //o//" src/winio.c
	# fprintf(stderr, "With modifiers: SHITF=%ld CTRL=%ld ALT=%ld\n", 
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_SHIFT,
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_CONTROL,
	# 	PDC_get_key_modifiers() & PDC_KEY_MODIFIER_ALT);



####
#### PDCursesMod especific patches
####

# Solve duplicated definitions ALT-ARROWS already in PDCursesMod
echo -e "\n\nPATCH: remove duplicated definitions."
sed -i.bak "/0x42[1234]/d" src/definitions.h
_diff

# PDCurses uses 64bit (chtype) for cell attributes instead of 32bit (int)
echo -e "\n\nPATCH: Improving from 256colors to true color."
sed -i.bak "/interface_color_pair/ {s/int/chtype/}" src/prototypes.h src/global.c
_diff
sed -i.bak "/int attributes/ {s/int/chtype/}" src/definitions.h
_diff
sed -i.bak "/bool parse_combination/ {s/int/chtype/}" src/rcfile.c
sed -i "/int attributes/ {s/int/chtype/}" src/rcfile.c
_diff

# Desambiguation of BACKSPACE vs ^H, or ENTER vs ^M and certain CTRL+key combos
echo -e "\n\nPATCH: Full key modifiers detection."
sed -i.bak "/get_kbinput(midwin, VISIBLE)/a\
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
_diff

# Fix wchar_t 16 bits limitation to display emojis and all the suplemental codepoints:
echo -e "\n\nPATCH: change to 32 bits wchar_t."
sed -i.bak '0,/#/s//#define wchar_t int\n&/' src/definitions.h curses/curses.h
_diff
echo -e "\n\nPATCH: fix for emojis input and output."
wget -q https://github.com/okibcn/nano-editor/raw/my-github-sync/curses/pdcurses/getch.c
wget -q https://github.com/okibcn/nano-editor/raw/my-github-sync/curses/wincon/pdcdisp.c
wget -q https://github.com/okibcn/nano-editor/raw/my-github-sync/curses/wincon/pdckbd.c
mv -f getch.c curses/pdcurses
mv -f pdc*.c curses/wincon
_diff

# Fix ALT+[NUMBER|LETTER] not working with PDCursesMod
echo -e "\n\nPATCH: ALT+[NUMBER|LETTER] not working."
sed -i "s/char)keystring\[2])/&\+\(\(unsigned char)keystring\[2]>\='9' \? ALT_A-\(int)'a' \: ALT_0-\(int)'0')/" src/global.c
_diff

# Solve mouse detection issue when using PDCursesMod advanced mouse mode
# sed -i "/undef ENABLE_MOUSE/d"   src/definitions.h

# BRANDING and VERSIONING
GITHUB_REPOSITORY="okibcn/nano-for-windows"
LAST_FULLVERSION="$(wget -q https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')" || echo "FIRST RELEASE!!!!"
LAST_VERSION="$(echo $LAST_FULLVERSION | awk -F .  '{print $1"."$2}')"  # last version without the subbuild
NANO_VERSION="$(git describe --tags 2>/dev/null | sed "s/.\{10\}$//")-$(git rev-list --count HEAD)"
NANO_DATE=$(TZ=UTC git show --quiet --date='format-local:%Y.%m.%d' --format="%cd")
if [ "${NANO_VERSION}" == "${LAST_VERSION}" ]; then
  # This is a new Windows build based on the same nano build, probably because there is a new curses patch
  SUBBUILD="$(echo $LAST_FULLVERSION | awk -F .  '{print $3}')"
  ((SUBBUILD=SUBBUILD+1))
  NANO_VERSION="${NANO_VERSION}.${SUBBUILD}"
fi
cd curses
CURSES="$(wget -q https://api.github.com/repos/Bill-Gray/PDCursesMod/releases/latest -O - | awk -F \" -v RS="," '/tag_name/ {print $(NF-1)}')"
CURSES_DATE=$(TZ=UTC git show --quiet --date='format-local:%Y.%m.%d' --format="%cd")
CURSES="PDCursesMod ${CURSES} build $(git rev-list --count HEAD), ${CURSES_DATE}"
cd ..
BUILD_DATE=$(TZ=UTC date +'%Y.%m.%d')

sed -i.bak 's/ GNU nano from git,//' src/nano.c
sed -i 's|Compiled options|Using '"${CURSES}"'\\n &|' src/nano.c
_diff
sed -i.bak '/SOMETHING = "REVISION/cSOMETHING = "REVISION \\"GNU nano for Windows, '"${NANO_VERSION}"' 64 bits, '"${BUILD_DATE}"'\\""' src/Makefile.am
_diff
echo -e "\n\nGNU nano version Tag: ${NANO_VERSION}, ${NANO_VERSION}\nUsing $CURSES"


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
