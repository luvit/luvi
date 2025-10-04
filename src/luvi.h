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
#include "uv.h"
#include "luv.h"
#ifndef WITH_PLAIN_LUA
#include "luajit.h"
#endif

#include <string.h>
#include <stdlib.h>
#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#else
#include <unistd.h>
#include <errno.h>
#endif

#if (LUA_VERSION_NUM < 503)
#include "compat-5.3.h"
#ifndef WITH_PLAIN_LUA
#undef luaL_traceback /* luajit has its own version */
#endif
#endif

#ifdef WITH_OPENSSL
#include "openssl.h"
#endif
#ifdef WITH_PCRE2
#include "pcre2.h"
int luaopen_rex_pcre2(lua_State* L);
#endif
#ifdef WITH_ZLIB
#include "zlib.h"
LUALIB_API int luaopen_zlib(lua_State * const L);
#endif
#ifdef WITH_WINSVC
#include "winsvc.h"
#include "winsvcaux.h"
#endif
#ifdef WITH_LPEG
int luaopen_lpeg(lua_State* L);
#endif
#ifdef WITH_PLAIN_LUA
LUALIB_API int luaopen_bit(lua_State *L);
#endif
#ifdef WITH_LJ_VMDEF
LUALIB_API int luaopen_vmdef(lua_State *L);
#endif

void luvi_openlibs(lua_State *L);

LUALIB_API int luaopen_init(lua_State *L);
LUALIB_API int luaopen_luvibundle(lua_State *L);
LUALIB_API int luaopen_luvipath(lua_State *L);
#endif

