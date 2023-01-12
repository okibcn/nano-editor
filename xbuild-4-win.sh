#!/bin/bash -e
sudo -E apt update && sudo apt upgrade -y
sudo -E apt install -y autoconf automake autopoint gcc mingw-w64 gettext git groff make pkg-config texinfo p7zip

git clone git://git.savannah.gnu.org/nano.git
cd nano
# git clone https://github.com/lhmouse/nano-win.git
# cd nano-win
wget -c "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz"
tar -xzvf ncurses-6.4.tar.gz

# realpath function doesn't exist on Windows, which isn't fully POSIX compliant.
echo " " >> ./src/definitions.h
echo "#ifdef _WIN32" >> ./src/definitions.h
echo "#define realpath(N,R) _fullpath((R),(N),_MAX_PATH)" >> ./src/definitions.h
echo "#endif" >> ./src/definitions.h

# Change default terminal to nothing
sed -i 's|vt220||g' ./src/nano.c

# Dirty fix homedir detection
sed -i 's|\"HOME\"|"USERPROFILE\"|g' ./src/utils.c

# Modify path expansion with backslashes
cat src/files.c \
  | sed "s,free(tilded);,free(tilded);\n\tfor(tilded = retval; \*tilded; ++tilded) if(\*tilded == 'SED_REPLACE') \*tilded = '/';,g" \
  | sed "s,path\[i\] != '/',path[i] != '/' \&\& path[i] != 'SED_REPLACE',g"  \
  | sed 's,SED_REPLACE,\\\\,g' > src/files2.c
mv src/files2.c src/files.c

./autogen.sh

PKG=$(pwd)/pkg
host="${1:-x86_64}-w64-mingw32"

# Build ncurses toolchain for local host 
mkdir -p build/ncurses
cd build/ncurses/
rm -rf *
../../ncurses-6.4/configure --prefix="${PKG}"  \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}
make -j$(($(nproc)*2))
# cross Build ncurses for destination host 
../../ncurses-6.4/configure --prefix="${PKG}"  \
  --enable-{widec,sp-funcs,termcap,term-driver,interop}  \
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  --host="${host}" 
make -j$(($(nproc)*2))
make install
cd ../..

# Build nano
mkdir -p build/nano
cd build/nano
rm -rf *
export PKG_CONFIG=false
export CFLAGS="-O2 -g3 -flto"
export CPPFLAGS="-D__USE_MINGW_ANSI_STDIO -I\"${PKG}/include\""
export LDFLAGS="-L\"${PKG}/lib/\" -static -flto"
export NCURSESW_CFLAGS="-I\"${PKG}/include/ncursesw\" -DNCURSES_STATIC"
export NCURSESW_LIBS="-lncursesw"
../../configure --host="${host}" --prefix="${PKG}"  \
  --enable-utf8 --disable-{nls,speller} \
  --sysconfdir="C:\ProgramData"  
make -j$(($(nproc)*2))
make install-strip
