BIN_ROOT=luvi-binaries/$(shell uname -s)_$(shell uname -m)

NPROCS:=1
OS:=$(shell uname -s)

ifeq ($(OS),Linux)
	NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
	NPROCS:=$(shell sysctl hw.ncpu | awk '{print $$2}')
endif

EXTRA_OPTIONS:=-j${NPROCS}

all: luvi

tiny:
	cmake -H. -Bbuild

large:
	cmake -H. -Bbuild -DWithOpenSSL=ON

static:
	cmake -H. -Bbuild -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF

luv/CMakeLists.txt:
	git submodule update --init --recursive
	git submodule update --recursive

build/Makefile: luv/CMakeLists.txt luv/luajit.cmake luv/uv.cmake
	cmake -H. -Bbuild

luvi: build/Makefile
	cmake --build build -- ${EXTRA_OPTIONS}

clean:
	rm -rf build

test: luvi
	LUVI_DIR=samples/test.app build/luvi 1 2 3 4

install: luvi
	cp build/luvi /usr/local/bin/luvi

link: luvi
	ln -sf `pwd`/build/luvi /usr/local/bin/luvi

publish-linux:
	git submodule update --init --recursive
	git submodule update --recursive
	mkdir -p $(BIN_ROOT)
	$(MAKE) clean tiny test && cp build/luvi $(BIN_ROOT)/luvi-tiny
	$(MAKE) clean static test && cp build/luvi $(BIN_ROOT)/luvi-static
	$(MAKE) clean large test && cp build/luvi $(BIN_ROOT)/luvi

publish-darwin:
	git submodule update --init --recursive
	git submodule update --recursive
	mkdir -p $(BIN_ROOT)
	$(MAKE) clean tiny test && cp build/luvi $(BIN_ROOT)/luvi-tiny
	$(MAKE) clean static test && cp build/luvi $(BIN_ROOT)/luvi
