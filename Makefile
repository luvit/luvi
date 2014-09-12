XCFLAGS=
#XCFLAGS+=-DLUAJIT_DISABLE_JIT
XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
#XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS
# verbose build
export Q=
MAKEFLAGS+=-e

CFLAGS+=-Iluv/libuv/include -Izlib -Izlib/contrib/minizip -Iluajit-2.0/src \
	-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 \
	-O3 -Wformat -Wall -pedantic -std=gnu99 -DLUAJIT_ENABLE_LUA52COMPAT

uname_S=$(shell uname -s)
ifeq (Darwin, $(uname_S))
	LDFLAGS+=-framework CoreServices -pagezero_size 10000 -image_base 100000000
else
	LDFLAGS=-lpthread -lm -ldl -Wl,-E -lrt
endif

SOURCE_FILES=\
	src/main.c \
	src/luvi.c \
	src/tinfl.c \
	src/lua/init.c \
	src/lua/zipreader.c \
	luv/src/dns.c \
	luv/src/fs.c \
	luv/src/handle.c \
	luv/src/luv.c \
	luv/src/luv.h \
	luv/src/misc.c \
	luv/src/pipe.c \
	luv/src/process.c \
	luv/src/stream.c \
	luv/src/tcp.c \
	luv/src/timer.c \
	luv/src/tty.c \
	luv/src/util.c

DEPS =\
	init.lua.o \
	zipreader.lua.o \
	luajit-2.0/src/libluajit.a \
	luv/libuv/libuv.a

all: luvi

gyp:
	# replace with configure
	tools/gyp/gyp --depth=$$PWD -D target_arch=x64 -Goutput_dir=$$PWD/out --generator-output $$PWD/out -f make -I common.gypi -D library=static_library
	$(MAKE) -C out

luv/libuv/libuv.a:
	$(MAKE) -C luv/libuv

luajit-2.0/src/libluajit.a:
	$(MAKE) -C luajit-2.0


%.lua.c: src/lua/%.lua luajit-2.0/src/libluajit.a
	cd luajit-2.0/src && ./luajit -bg ../../$< ../../$@ && cd ../..

%.lua.o: %.lua.c

luvi: ${SOURCE_FILES} ${DEPS}
	$(CC) -c src/main.c ${CFLAGS} -o luvi.o
	$(CC) luvi.o ${DEPS} ${LDFLAGS} -o $@
	rm luvi.o

sample-app.zip: sample-app sample-app/main.lua sample-app/greetings.txt sample-app/add/init.lua
	cd sample-app && zip -r -9 ../sample-app.zip . && cd ..

app: luvi sample-app.zip
	cat $^ > $@
	chmod +x $@

clean-all: clean
	$(MAKE) -C luajit-2.0 clean
	$(MAKE) -C luv clean
	$(MAKE) -C luv/libuv clean

clean:
	rm -f luvi *.o app sample-app.zip *.lua.c
