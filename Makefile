XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
#XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS

CFLAGS+=-Iluv/libuv/include -Izlib -Izlib/contrib/minizip -Iluajit-2.0/src \
	-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 \
	-O3 -Wformat -Wall -pedantic -std=gnu99

uname_S=$(shell uname -s)
ifeq (Darwin, $(uname_S))
	LDFLAGS+=-framework CoreServices -pagezero_size 10000 -image_base 100000000
else
	LDFLAGS=-lpthread -lm -ldl
endif

SOURCE_FILES=\
	main.c \
	lzlib.c \
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
	zlib/libz.a

all: luvi

luv/libuv/libuv.a:
	$(MAKE) -C luv/libuv

luajit-2.0/src/libluajit.a:
	$(MAKE) -C luajit-2.0

zlib/libz.a:
	$(MAKE) -C zlib


luvi: ${SOURCE_FILES} ${DEPS}
	$(CC) -c main.c ${CFLAGS} -o luvi.o
	$(CC) luvi.o ${DEPS} ${LDFLAGS} -o $@
	rm luvi.o

clean:
	$(MAKE) -C luajit-2.0 clean
	$(MAKE) -C luv clean
	$(MAKE) -C luv/libuv clean
	$(MAKE) -C zlib clean
	rm -f luvi
