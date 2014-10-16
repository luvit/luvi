
all: luvi

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

