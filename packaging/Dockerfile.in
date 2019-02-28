from multiarch/ubuntu-core:@@ARCH@@-bionic

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y build-essential cmake git gzip

WORKDIR /src
