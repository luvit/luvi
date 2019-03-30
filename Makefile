LUVI_TAG=$(shell git describe)
LUVI_ARCH=$(shell uname -s)_$(shell uname -m)
LUVI_PUBLISH_USER?=luvit
LUVI_PUBLISH_REPO?=luvi
LUVI_PREFIX?=/usr/local
LUVI_BINDIR?=$(LUVI_PREFIX)/bin

OS:=$(shell uname -s)
ARCH:=$(shell uname -m)

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

# Configure the build with shared openssl
regular-shared:
	cmake $(CMAKE_FLAGS) $(CPACK_FLAGS) -DWithOpenSSL=ON -DWithSharedOpenSSL=ON -DWithPCRE=ON -DWithLPEG=ON -DWithSharedPCRE=OFF

package: deps/luv/CMakeLists.txt
	cmake --build build -- package

# In case the user forgot to pull in submodules, grab them.
deps/luv/CMakeLists.txt:
	git submodule update --init --recursive

clean:
	rm -rf build luvi-*

test: luvi
	rm -f test.bin
	build/luvi samples/test.app -- 1 2 3 4
	build/luvi samples/test.app -o test.bin
	./test.bin 1 2 3 4
	rm -f test.bin

install: luvi
	install -p build/luvi $(LUVI_BINDIR)/

uninstall:
	rm -f /usr/local/bin/luvi

reset:
	git submodule update --init --recursive && \
	git clean -f -d && \
	git checkout .

luvi-src.tar.gz:
	echo ${LUVI_TAG} > VERSION && \
	COPYFILE_DISABLE=true tar -czvf ../luvi-src.tar.gz \
	  --exclude 'luvi-src.tar.gz' --exclude '.git*' --exclude build . && \
	mv ../luvi-src.tar.gz . && \
	rm VERSION


travis-publish:	reset luvi-src.tar.gz travis-tiny travis-regular-asm
	$(MAKE)
	mv luvi-src.tar.gz luvi-src-${LUVI_TAG}.tar.gz

travis-tiny: reset tiny
	$(MAKE)
	mv build/luvi luvi-tiny-$(OS)_$(ARCH)

travis-regular-asm: reset regular-asm
	$(MAKE)
	mv build/luvi luvi-regular-$(OS)_$(ARCH)

linux-build: linux-build-box-regular linux-build-box32-regular linux-build-box-tiny linux-build-box32-tiny

linux-build-box-regular: luvi-src.tar.gz
	rm -rf build && mkdir -p build
	cp packaging/holy-build.sh luvi-src.tar.gz build
	mkdir -p build
	docker run -t -i --rm \
		  -v `pwd`/build:/io phusion/holy-build-box-64:latest bash /io/holy-build.sh regular-asm
	mv build/luvi luvi-regular-Linux_x86_64

linux-build-box32-regular: luvi-src.tar.gz
	rm -rf build && mkdir -p build
	cp packaging/holy-build.sh luvi-src.tar.gz build
	docker run -t -i --rm \
		  -v `pwd`/build:/io phusion/holy-build-box-32:latest linux32 bash /io/holy-build.sh regular-asm
	mv build/luvi luvi-regular-Linux_i686

linux-build-box-tiny: luvi-src.tar.gz
	rm -rf build && mkdir -p build
	cp packaging/holy-build.sh luvi-src.tar.gz build
	mkdir -p build
	docker run -t -i --rm \
		  -v `pwd`/build:/io phusion/holy-build-box-64:latest bash /io/holy-build.sh tiny
	mv build/luvi luvi-tiny-Linux_x86_64

linux-build-box32-tiny: luvi-src.tar.gz
	rm -rf build && mkdir -p build
	cp packaging/holy-build.sh luvi-src.tar.gz build
	docker run -t -i --rm \
		  -v `pwd`/build:/io phusion/holy-build-box-32:latest linux32 bash /io/holy-build.sh tiny
	mv build/luvi luvi-tiny-Linux_i686

publish-src: reset luvi-src.tar.gz
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-src.tar.gz --name luvi-src-${LUVI_TAG}.tar.gz

publish:
	$(MAKE) clean publish-tiny
	$(MAKE) clean publish-regular

publish-linux: reset
	$(MAKE) linux-build && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-regular-Linux_i686 --name luvi-regular-Linux_i686 && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-regular-Linux_x86_64 --name luvi-regular-Linux_x86_64 && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-tiny-Linux_x86_64 --name luvi-tiny-Linux-x86_64 && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file luvi-tiny-Linux_i686 --name luvi-tiny-Linux-i686

publish-tiny: reset
	$(MAKE) tiny test && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-tiny-${LUVI_ARCH}

publish-regular: reset
	$(MAKE) regular-asm test && \
	github-release upload --user ${LUVI_PUBLISH_USER} --repo ${LUVI_PUBLISH_REPO} --tag ${LUVI_TAG} \
	  --file build/luvi --name luvi-regular-${LUVI_ARCH}
