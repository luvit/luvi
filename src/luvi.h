#ifndef LUVI_H
#define LUVI_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "../deps/luv/libuv/include/uv.h"
#include "../deps/luv/src/luv.h"

#include <string.h>
#include <stdlib.h>
#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#else
#include <unistd.h>
#include <errno.h>
#endif

#endif
