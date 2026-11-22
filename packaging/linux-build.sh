#!/bin/bash

set -xeuo pipefail

ARCH=$1
BUILD_TYPE=$2
LUA_ENGINE=$3

NPROCS=$(grep -c ^processor /proc/cpuinfo)

# Retries a command a few times, given that the CentOS 7 vault mirrors used by
# the manylinux2014 images are flaky, and quay.io/DNS hiccups happen as well.
retry() {
    local n=1
    until "$@"; do
        if [ "$n" -ge 5 ]; then
            echo "Command failed after $n attempts: $*" >&2
            return 1
        fi
        sleep 5
        n=$((n + 1))
    done
}

if which yum; then
    if [ "$ARCH" != "i686" ]; then
        retry yum install -y epel-release
        retry yum install -y cmake3
    else # the version of cmake install is too old, and cmake3 is not available for i686
        retry yum install -y openssl-devel

        retry curl -fLO https://github.com/Kitware/CMake/releases/download/v3.22.3/cmake-3.22.3.tar.gz
        tar -zxf cmake-3.22.3.tar.gz
        cd cmake-3.22.3
        ./bootstrap --parallel=$NPROCS
        make -j$NPROCS
        make install
        cd ..
    fi
    retry yum install -y perl-core
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
