FROM debian:testing AS clone
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y qemu-user-static git
RUN git clone --recursive https://github.com/luvit/luvi.git --branch=v2.8.0

FROM clone AS host
RUN apt-get install -y build-essential ninja-build cmake
ENV GENERATOR=Ninja
WORKDIR /luvi
RUN make tiny
RUN make

FROM arm32v5/debian:testing AS arm32v5
COPY --from=clone /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y build-essential ninja-build cmake git
ENV GENERATOR=Ninja
COPY --from=clone /luvi /luvi
WORKDIR /luvi
RUN make tiny
RUN make

FROM arm32v7/debian:testing AS arm32v7
COPY --from=clone /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y build-essential ninja-build cmake git
COPY --from=clone /luvi /luvi
WORKDIR /luvi
RUN make tiny
RUN make

FROM arm64v8/debian:testing AS arm64v8
COPY --from=clone /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y build-essential ninja-build cmake git
ENV GENERATOR=Ninja
COPY --from=clone /luvi /luvi
WORKDIR /luvi
RUN make tiny
RUN make

FROM scratch
COPY --from=host /luvi/build/luvi luvi-tiny
COPY --from=arm32v5 /luvi/build/luvi luvi-tiny-arm32v5
COPY --from=arm32v7 /luvi/build/luvi luvi-tiny-arm32v7
COPY --from=arm64v8 /luvi/build/luvi luvi-tiny-arm64v8
