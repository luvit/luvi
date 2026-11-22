#!/bin/bash

set -xeuo pipefail

ARCH=$1
BUILD_TYPE=$2
LUA_ENGINE=$3

NPROCS=$(grep -c ^processor /proc/cpuinfo)

# Retries a command a few times, given that quay.io and distro mirrors
# occasionally fail with transient errors.
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
    # manylinux_2_28 (AlmaLinux 8 based) provides cmake in AppStream; on older
    # images it is only available as cmake3 from EPEL.
    retry yum install -y cmake || retry yum install -y cmake3
    retry yum install -y perl-core
else
    apk add cmake
fi

git config --global --add safe.directory /github/workspace
git config --global --add safe.directory /github/workspace/deps/luv/deps/luajit

make $BUILD_TYPE WITH_LUA_ENGINE=$LUA_ENGINE
make
make test
