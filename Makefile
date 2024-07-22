
###################################################################################################
# Default build options
###################################################################################################
#  NPROCS:                Number of processors to use for parallel jobs
#  GENERATOR:             CMake generator to configure and build with
#  PREFIX:                Where to install luvi, defaults to /usr/local or C:\Program Files\luvit
#  BINPREFIX:             Where to install luvi binary, defaults to $PREFIX/bin
#  EXTRA_CONFIGURE_FLAGS: Extra options to pass to cmake when configuring
#  EXTRA_BUILD_FLAGS:     Extra options to pass to make when building
#
#  CMAKE_BUILD_TYPE:   The cmake build type to use, defaults to Release
#  WITH_AMALG:         Whether to build the lua amalgamated, will use more memory but is faster
#  WITH_LUA_ENGINE:    Which lua engine to use, defaults to LuaJIT
#  WITH_SHARED_LIBLUV: Whether to use libluv as a shared library.
#    			       Note: Shared libluv implies shared libuv and luajit.
#
#  WITH_{OPENSSL,PCRE,LPEG,ZLIB}: Whether to include the given library in the build
#  WITH_SHARED_{OPENSSL,PCRE,LPEG,ZLIB}: Whether to use shared or static versions of the given library
###################################################################################################

all: default

ifdef MAKEDIR: ########################
!ifdef MAKEDIR #### Start of nmake ####

!ifndef CMAKE_BUILD_TYPE
CMAKE_BUILD_TYPE = Release
!endif

!ifndef WITH_AMALG
WITH_AMALG = ON
!endif

!ifndef WITH_LUA_ENGINE
WITH_LUA_ENGINE = LuaJIT
!endif

!ifndef WITH_SHARED_LIBLUV
WITH_SHARED_LIBLUV = OFF
!endif

!ifndef WITH_OPENSSL
WITH_OPENSSL = ON
!endif

!ifndef WITH_PCRE2
WITH_PCRE2 = ON
!endif

!ifndef WITH_LPEG
WITH_LPEG = ON
!endif

!ifndef WITH_ZLIB
WITH_ZLIB = OFF
!endif

!ifndef WITH_OPENSSL_ASM
WITH_OPENSSL_ASM = ON
!endif

!ifndef WITH_SHARED_OPENSSL
WITH_SHARED_OPENSSL = OFF
!endif

!ifndef WITH_SHARED_PCRE2
WITH_SHARED_PCRE2 = OFF
!endif

!ifndef WITH_SHARED_LPEG
WITH_SHARED_LPEG = OFF
!endif

!ifndef WITH_SHARED_ZLIB
WITH_SHARED_ZLIB = OFF
!endif

!ifndef PREFIX
PREFIX = C:\Program Files\luvit
!endif

!ifndef BINPREFIX
BINPREFIX = $(PREFIX)\bin
!endif

!ifndef BUILD_PREFIX
BUILD_PREFIX = build
!endif

RMR      = cmd /c rmdir /s /q
RM       = cmd /c del /f
INSTALL  = cmd /c copy /y
LUVI     = cmd /c $(BUILD_PREFIX)\$(CMAKE_BUILD_TYPE)\luvi.exe
TEST_BIN = cmd /c test.bin

!ifndef CMAKE
CMAKE = cmake
!endif

!else ####   End of nmake ####
else  #### Start of gmake ####

CMAKE_BUILD_TYPE ?= Release

WITH_AMALG ?= ON
WITH_LUA_ENGINE ?= LuaJIT
WITH_SHARED_LIBLUV ?= OFF

WITH_OPENSSL ?= ON
WITH_PCRE2   ?= ON
WITH_LPEG    ?= ON
WITH_ZLIB    ?= OFF

WITH_OPENSSL_ASM    ?= ON
WITH_SHARED_OPENSSL ?= OFF
WITH_SHARED_PCRE2   ?= OFF
WITH_SHARED_LPEG    ?= OFF
WITH_SHARED_ZLIB    ?= OFF

OS := $(shell uname -s)
ifeq ($(OS),Windows_NT)
	PREFIX ?= C:\Program Files\luvit
else
	PREFIX ?= /usr/local
endif

BINPREFIX ?= $(PREFIX)/bin
BUILD_PREFIX ?= build

RMR      = rm -rf
RM       = rm -f
INSTALL  = install -p
LUVI     = $(BUILD_PREFIX)/luvi
TEST_BIN = ./test.bin

CMAKE   ?= cmake

endif    ####   End of gmake ####
!endif : ########################

###############################################################################

CONFIGURE_FLAGS = \
	-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
	-DWITH_AMALG=$(WITH_AMALG) \
	-DWITH_LUA_ENGINE=$(WITH_LUA_ENGINE) \
	-DWithSharedLibluv=$(WITH_SHARED_LIBLUV)

CONFIGURE_REGULAR_FLAGS = $(CONFIGURE_FLAGS) \
	-DWithOpenSSL=$(WITH_OPENSSL) \
	-DWithPCRE2=$(WITH_PCRE2) \
	-DWithLPEG=$(WITH_LPEG) \
	-DWithZLIB=$(WITH_ZLIB) \
	-DWithOpenSSLASM=$(WITH_OPENSSL_ASM) \
	-DWithSharedOpenSSL=$(WITH_SHARED_OPENSSL) \
	-DWithSharedPCRE2=$(WITH_SHARED_PCRE2) \
	-DWithSharedLPEG=$(WITH_SHARED_LPEG) \
	-DWithSharedZLIB=$(WITH_SHARED_ZLIB)

ifdef MAKEDIR: ########################
!ifdef MAKEDIR #### Start of nmake ####

!ifdef GENERATOR
CONFIGURE_FLAGS = "$(CONFIGURE_FLAGS) -G$(GENERATOR)"
!endif

!ifdef ARCH
CONFIGURE_FLAGS = "$(CONFIGURE_FLAGS) -A$(ARCH)"
!endif

!else ####   End of nmake ####
else  #### Start of gmake ####

ifdef GENERATOR
	CONFIGURE_FLAGS += -G"$(GENERATOR)"
endif

ifdef NPROCS
	BUILD_OPTIONS += -j$(NPROCS)
endif

endif    ####   End of gmake ####
!endif : ########################

### Build targets

default: luvi

# This does the actual build and configures as default flavor is there is no build folder.
luvi: $(BUILD_PREFIX)
	$(CMAKE) --build $(BUILD_PREFIX) --config $(CMAKE_BUILD_TYPE) -- $(BUILD_OPTIONS) $(EXTRA_OPTIONS)

### Directories and dependencies

# Ensure the build prefix exists, ie. we have configured the build
$(BUILD_PREFIX):
	@echo "Please run 'make tiny' or 'make regular' first to configure"

# In case the user forgot to pull in submodules, grab them.
deps/luv/CMakeLists.txt:
	git submodule update --init --recursive

### Configuration targets

# Configure the build with minimal dependencies
tiny: deps/luv/CMakeLists.txt
	$(CMAKE) -H. -B$(BUILD_PREFIX) $(CONFIGURE_FLAGS) $(EXTRA_CONFIGURE_FLAGS)

# Configure the build with any libraries requested
regular: deps/luv/CMakeLists.txt
	$(CMAKE) -H. -B$(BUILD_PREFIX) $(CONFIGURE_REGULAR_FLAGS) $(EXTRA_CONFIGURE_FLAGS)

### Phony targets

.PHONY: clean test install uninstall reset
clean:
	$(RMR) $(BUILD_PREFIX) test.bin

install: luvi
	install -p $(BUILD_PREFIX)/luvi $(BINPREFIX)/luvi

uninstall:
	$(RM) $(BINPREFIX)/luvi

test: luvi
	$(RM) test.bin
	$(LUVI) samples/test.app -- 1 2 3 4
	$(LUVI) samples/test.app -o test.bin
	$(TEST_BIN) 1 2 3 4
	$(RM) test.bin

reset:
	git submodule update --init --recursive && \
	git clean -f -d && \
	git checkout .
