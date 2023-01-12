#!/bin/bash -e

./xbuild-4-win.sh x86_64
./xbuild-4-win.sh i686

_pkgversion="$(git describe --tags || echo "v0.0.0-0-unknown")"
_revision="$(git rev-list --count HEAD)"

strip -s pkg_{i686,x86_64}-w64-mingw32/bin/nano.exe
cp doc/sample.nanorc.in .nanorc
7z a -aoa -mmt"$(nproc)" --  \
  "nano-win_${_revision}_${_pkgversion}.7z"  \
  pkg_{i686,x86_64}-w64-mingw32/{bin/nano.exe,share/{nano,doc}/}  \
  .nanorc
