#!/bin/bash

set -xeuo pipefail

ARCH=$1
BUILD_TYPE=$2
LUA_ENGINE=$3

NPROCS=$(grep -c ^processor /proc/cpuinfo)

if which yum; then
    if [ "$ARCH" != "i686" ]; then
        yum install -y epel-release
        yum install -y cmake3
    else # the version of cmake install is too old, and cmake3 is not available for i686
        yum install -y openssl-devel

        curl -fLO https://github.com/Kitware/CMake/releases/download/v3.22.3/cmake-3.22.3.tar.gz
        tar -zxf cmake-3.22.3.tar.gz
        cd cmake-3.22.3
        ./bootstrap --parallel=$NPROCS
        make -j$NPROCS
        make install
        cd ..
    fi
    yum install -y perl-core
else
    apk add cmake
fi

git config --global --add safe.directory /github/workspace
git config --global --add safe.directory /github/workspace/deps/luv/deps/luajit

WITH_OPENSSL_ASM=ON
if [ "$ARCH" == "i686" ]; then
    WITH_OPENSSL_ASM=OFF
fi

make $BUILD_TYPE WITH_LUA_ENGINE=$LUA_ENGINE WITH_OPENSSL_ASM=$WITH_OPENSSL_ASM
make
make test
