
all: luvi

luv/CMakeLists.txt:
	git submodule update --init --recursive
	git submodule update --recursive

build/Makefile: luv/CMakeLists.txt luv/luajit.cmake luv/uv.cmake
	cmake -H. -Bbuild

build/luvi: build/Makefile
	cmake --build build --config Release

luvi: build/luvi
	ln -sf build/luvi

clean:
	rm -rf build luvi

test: luvi build/luvi
	./luvi samples/test.app

install: build/luvi
	cp luvi /usr/local/bin/luvi

link: build/luvi
	ln -sf `pwd`/build/luvi /usr/local/bin/luvi
