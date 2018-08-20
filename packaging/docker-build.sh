#!/bin/bash

set -eou pipefail
set -x

BUILD_TYPE=${1:-regular-asm}
BUILD_NAME=${2:-regular}

if [[ $BUILD_TYPE = *"tiny"* ]]; then
  BUILD_NAME=tiny
fi

cd $(dirname $0)
echo "Build Type: ${BUILD_TYPE}"

build() {
  arch=$1
  tmpdir=$(mktemp -d)
  image_name=luvi-builder-$arch

  sed "s:@@ARCH@@:$arch:g" Dockerfile.in > $tmpdir/Dockerfile
  docker build --rm -t $image_name -f $tmpdir/Dockerfile .
  docker run -v $PWD/..:/src $image_name make clean
  docker run -v $PWD/..:/src -e SHAREDSSL=false $image_name make $BUILD_TYPE luvi
  cp -f ../build/luvi ../packaging/luvi-$BUILD_NAME-linux_$arch
}

docker run --rm --privileged multiarch/qemu-user-static:register --reset

ARCHS=("armhf" "x86" "x86_64")
for i in "${!ARCHS[@]}"; do
  arch=${ARCHS[$i]}
  build $arch
done
