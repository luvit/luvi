#!/bin/bash

set -eou pipefail
set -x

cd $(dirname $0)

build() {
  arch=$1
  build_name=$2
  tmpdir=$(mktemp -d)
  image_name=luvi-builder-$arch

  echo "Building: $arch $build_name"

  sed "s:@@ARCH@@:$arch:g" Dockerfile.in > $tmpdir/Dockerfile
  docker build --rm -t $image_name -f $tmpdir/Dockerfile .
  docker run -v $PWD/..:/src $image_name make clean
  docker run -v $PWD/..:/src -e SHAREDSSL=false $image_name make $build_name luvi

  if [[ "$build_name" == "regular-asm" ]]; then
    build_name="regular"
  fi

  cp -f ../build/luvi ../packaging/luvi-$build_name-Linux_$arch

  rm -rf $tmpdir
}

docker run --rm --privileged multiarch/qemu-user-static:register --reset

ARCHS=("armhf" "x86" "x86_64")
BUILD_NAMES=("tiny" "regular-asm")
for i in "${!ARCHS[@]}"; do
  for j in "${!BUILD_NAMES[@]}"; do
    build ${ARCHS[$i]} ${BUILD_NAMES[$j]}
  done
done
