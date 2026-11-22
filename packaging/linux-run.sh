#!/bin/bash

set -xeuo pipefail

LIBC=$1
ARCH=$2

shift 2

if [ x$LIBC == xglibc ]; then
    container_host="quay.io/pypa/manylinux2014_$ARCH"
else    
    container_host="quay.io/pypa/musllinux_1_2_$ARCH"
fi

# try to pull the image 3 times, because quay.io sometimes fails
for i in 1 2 3; do
    docker pull $container_host && break
done

# Workaround networking issues on the container. Use `--network host` and mount
# the `/etc/resolv.conf` from the outside to make mirrors reachable.
docker run --rm \
    --network host \
    -v /etc/resolv.conf:/etc/resolv.conf \
    -v "$GITHUB_WORKSPACE":"/github/workspace" \
    -w /github/workspace \
    $container_host \
    /bin/bash packaging/linux-build.sh $ARCH $@
