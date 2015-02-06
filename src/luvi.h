/*
 *  Copyright 2015 The Luvit Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
#ifndef LUVI_H
#define LUVI_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "../deps/luv/deps/libuv/include/uv.h"
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

#ifdef WITH_OPENSSL
#include "openssl.h"
#endif
#ifdef WITH_ZLIB
LUALIB_API int luaopen_zlib(lua_State * const L);
#endif
#ifdef WITH_WINSVC
#include "winsvc.h"
#include "winsvcaux.h"
#endif

#endif
