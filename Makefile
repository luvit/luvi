XCFLAGS+=-DLUAJIT_ENABLE_LUA52COMPAT
#XCFLAGS+=-DLUA_USE_APICHECK
export XCFLAGS


CFLAGS=-Iluv/libuv/include -g -Iluajit-2.0/src \
	-DLUV_STACK_CHECK -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 \
	-Wall -Werror -fPIC

uname_S=$(shell uname -s)
ifeq (Darwin, $(uname_S))
	LDFLAGS=-framework CoreServices -pagezero_size 10000 -image_base 100000000
else
	LDFLAGS=-lrt
endif

SOURCE_FILES=\
	main.c \
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

all: luvi

luv/libuv/libuv.a:
	CPPFLAGS=-fPIC $(MAKE) -C luv/libuv

luajit-2.0/src/libluajit.a:
	$(MAKE) -C luajit-2.0


luvi: ${SOURCE_FILES} luv/libuv/libuv.a luajit-2.0/src/libluajit.a
	$(CC) -c main.c ${CFLAGS} -o luvi.o
	$(CC) luvi.o luv/libuv/libuv.a luajit-2.0/src/libluajit.a ${LDFLAGS} -o $@
	rm luvi.o

clean:
	rm -f luvi
