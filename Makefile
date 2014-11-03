
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
	cmake --build build --config Debug

clean:
	rm -rf build

test: luvi
	LUVI_DIR=samples/test.app build/luvi 1 2 3 4

install: luvi
	cp build/luvi /usr/local/bin/luvi

link: luvi
	ln -sf `pwd`/build/luvi /usr/local/bin/luvi
