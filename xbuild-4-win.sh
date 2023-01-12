#!/bin/bash -e
sudo -E apt update && sudo apt upgrade -y
sudo -E apt install -y autoconf automake autopoint gcc mingw-w64 gettext git groff make pkg-config texinfo p7zip-full

# Download sources
git clone git://git.savannah.gnu.org/nano.git
cd nano
git log -n 1
./autogen.sh
git clone https://github.com/mirror/ncurses.git
cd ncurses
git log -n 1
cd ..

# >realpath< function doesn't exist on Windows, which isn't fully POSIX compliant.
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
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}
make -j$(($(nproc)*2))
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
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  --host="${TOOLCHAIN}" 
make -j$(($(nproc)*2))
make install
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
  --sysconfdir="C:\ProgramData"  
make -j$(($(nproc)*2))
make install-strip
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
  --disable-{shared,database,rpath,home-terminfo,db-install,getcap}  \
  --without-{progs,ada,cxx-binding,manpages,pthread,debug,tests,libtool}  --host="${TOOLCHAIN}" 
make -j$(($(nproc)*2))
make install
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
  --sysconfdir="C:\ProgramData"  
make -j$(($(nproc)*2))
make install-strip
cd ../..

 ############################
##                          ##
##      CREATE PACKAGE      ##
##                          ##
 ############################

NANO_VERSION="$(git describe --tags || echo "v0.0.0-0-unknown")"
NANO_REVISION="$(git rev-list --count HEAD)"

strip -s pkg_{i686,x86_64}-w64-mingw32/bin/nano.exe
cp doc/sample.nanorc.in .nanorc
7z a -aoa -mmt"$(nproc)" --  \
  "nano-editor_${NANO_REVISION}_${NANO_VERSION}.7z"  \
  pkg_{i686,x86_64}-w64-mingw32/{bin/nano.exe,share/{nano,doc}/}  \
  .nanorc
