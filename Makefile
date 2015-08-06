LUVI_TAG=$(shell git describe)
LUVI_ARCH=$(shell uname -s)_$(shell uname -m)
LUVI_PUBLISH_USER?=luvit
LUVI_PUBLISH_REPO?=luvi

OS:=$(shell uname -s)

CMAKE_FLAGS+= -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
ifdef GENERATOR
	CMAKE_FLAGS+= -G"${GENERATOR}"
endif

ifdef WITHOUT_AMALG
	CMAKE_FLAGS+= -DWITH_AMALG=OFF
endif

WITH_SHARED_LIBLUV ?= OFF

CMAKE_FLAGS += \
	-DWithSharedLibluv=$(WITH_SHARED_LIBLUV)

CPACK_FLAGS=-DWithPackageSH=ON -DWithPackageTGZ=ON -DWithPackageTBZ2=ON
ifdef CPACK_DEB
	CPACK_FLAGS=-DWithPackageDEB=ON
endif

ifdef CPACK_RPM
	CPACK_FLAGS=-DWithPackageRPM=ON
endif

ifdef CPACK_NSIS
	CPACK_FLAGS=-DWithPackageNSIS=ON
endif

ifdef CPACK_BUNDLE
	CPACK_FLAGS=-DWithPackageBUNDLE=ON
endif

ifndef NPROCS
ifeq ($(OS),Linux)
	NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
	NPROCS:=$(shell sysctl hw.ncpu | awk '{print $$2}')
endif
endif

ifdef NPROCS
  EXTRA_OPTIONS:=-j${NPROCS}
endif

# This does the actual build and configures as default flavor is there is no build folder.
luvi: build
	cmake --build build -- ${EXTRA_OPTIONS}

build:
	@echo "Please run tiny' or 'regular' make target first to configure"

# Configure the build with minimal dependencies
tiny: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS)

# Configure the build with openssl statically included
regular: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS) -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -DWithPCRE=ON -DWithLPEG=ON -DWithSharedPCRE=OFF

regular-asm: deps/luv/CMakeLists.txt
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS) -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -DWithOpenSSLASM=ON -DWithPCRE=ON -DWithLPEG=ON -DWithSharedPCRE=OFF

package: deps/luv/CMakeLists.txt
	cmake --build build -- package

# In case the user forgot to pull in submodules, grab them.
deps/luv/CMakeLists.txt:
	git submodule update --init --recursive

clean:
	rm -rf build luvi-src.tar.gz

test: luvi
	rm -f test.bin
	build/luvi samples/test.app -- 1 2 3 4
	build/luvi samples/test.app -o test.bin
	./test.bin 1 2 3 4
	rm -f test.bin
install: luvi
	install -p build/luvi /usr/local/bin

uninstall:
	rm -f /usr/local/bin/luvi

reset:
	git submodule update --init --recursive && \
	git clean -f -d && \
	git checkout .

luvi-src.tar.gz:
	echo ${LUVI_TAG} > VERSION && \
	tar -czvf luvi-src.tar.gz \
	  --exclude 'luvi-src.tar.gz' --exclude '.git*' --exclude build . && \
	rm VERSION

publish-src: reset luvi-src.tar.gz
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-src.tar.gz --name luvi-src-${LUVI_TAG}.tar.gz

publish:
	$(MAKE) clean publish-tiny
	$(MAKE) clean publish-regular

publish-tiny: reset
	$(MAKE) tiny test && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-tiny-${LUVI_ARCH}

publish-regular: reset
	$(MAKE) regular-asm test && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-regular-${LUVI_ARCH}
