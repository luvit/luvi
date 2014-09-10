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
	main.c \
	env.c \
	inflate.c \
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
	luajit-2.0/src/libluajit.a \
	luv/libuv/libuv.a \
	init.lua.o \
	zipreader.lua.o \
	utils.lua.o

all: luvi

gyp:
	# replace with configure
	tools/gyp/gyp --depth=$$PWD -D target_arch=x64 -Goutput_dir=$$PWD/out --generator-output $$PWD/out -f make -I common.gypi -D library=static_library
	make -C out -j4 V=1

luv/libuv/libuv.a:
	$(MAKE) -C luv/libuv

luajit-2.0/src/libluajit.a:
	$(MAKE) -C luajit-2.0


%.lua.o: lib/%.lua luajit-2.0/src/libluajit.a
	luajit-2.0/src/luajit -bg $< $@

luvi: ${SOURCE_FILES} ${DEPS}
	$(CC) -c main.c ${CFLAGS} -o luvi.o
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
	rm -f luvi *.o app sample-app.zip
