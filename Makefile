BIN_ROOT=luvi-binaries/$(shell uname -s)_$(shell uname -m)

NPROCS:=1
OS:=$(shell uname -s)

CMAKE_FLAGS+= -H. -Bbuild
ifdef GENERATOR
	CMAKE_FLAGS+= -G"${GENERATOR}"
endif

ifeq ($(OS),Linux)
	NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
	NPROCS:=$(shell sysctl hw.ncpu | awk '{print $$2}')
endif

EXTRA_OPTIONS:=-j${NPROCS}

# This does the actual build and configures as default flavor is there is no build folder.
luvi: build
	cmake --build build -- ${EXTRA_OPTIONS}

# The default flavor is tiny
build: tiny

# Configure the build with minimal dependencies
tiny: luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS)

# Configure the build with everything, use shared libs when possible
large: luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) -DWithOpenSSL=ON -DWithZLIB=ON

# Configure the build with everything, but statically link the deps
static: luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -DWithZLIB=ON -DWithSharedZLIB=OFF

# In case the user forgot to pull in submodules, grab them.
luv/CMakeLists.txt:
	git submodule update --init --recursive

clean:
	rm -rf build

test: luvi
	rm -f test.bin
	LUVI_APP=samples/test.app build/luvi 1 2 3 4
	LUVI_APP=samples/test.app LUVI_TARGET=test.bin build/luvi
	LUVI_app= ./test.bin 1 2 3 4
	rm -f test.bin
install: luvi
	install -p build/luvi /usr/local/bin

uninstall:
	rm -f /usr/local/bin/luvi

publish-linux:
	git submodule update --init --recursive
	mkdir -p $(BIN_ROOT)
	$(MAKE) clean tiny test && cp build/luvi $(BIN_ROOT)/luvi-tiny
	$(MAKE) clean static test && cp build/luvi $(BIN_ROOT)/luvi-static
	$(MAKE) clean large test && cp build/luvi $(BIN_ROOT)/luvi

publish-raspberry:
	git submodule update --init --recursive
	mkdir -p $(BIN_ROOT)
	$(MAKE) clean tiny test && cp build/luvi $(BIN_ROOT)/luvi-tiny
	$(MAKE) clean large test && cp build/luvi $(BIN_ROOT)/luvi

publish-darwin:
	git submodule update --init --recursive
	mkdir -p $(BIN_ROOT)
	$(MAKE) clean tiny test && cp build/luvi $(BIN_ROOT)/luvi-tiny
	$(MAKE) clean static test && cp build/luvi $(BIN_ROOT)/luvi
