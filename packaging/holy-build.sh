#!/bin/bash

BUILD_TYPE=${1:-regular-asm}
NPROCS=$(grep -c ^processor /proc/cpuinfo)

echo "Build Type: ${BUILD_TYPE}"

set -e

# Activate Holy Build Box environment.
source /hbb_exe/activate

set -x

# Extract and enter source
# Use /luvi dir to avoid CMake assertion failure in /
mkdir -p luvi
tar xzf /io/luvi-src.tar.gz --directory luvi
cd luvi
make ${BUILD_TYPE}
make -j${NPROCS}
ldd build/luvi
libcheck build/luvi
# holy-build-box adds -g to CFLAGS, so we need to strip debug symbols
strip --strip-debug build/luvi
cp build/luvi /io
