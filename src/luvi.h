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

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "uv.h"
#include "luv.h"

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
#ifdef WITH_PCRE
#include "pcre.h"
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
#endif

#if (LUA_VERSION_NUM >= 502)
# undef luaL_register
# define luaL_register(L,n,f) \
               { if ((n) == NULL) luaL_setfuncs(L,f,0); else luaL_newlib(L,f); }

# undef luaL_checkint
# define luaL_checkint(L,i) ((int)luaL_checkinteger(L,(i)))
# undef luaL_optint
# define luaL_optint(L,i,d) ((int)luaL_optinteger(L,(i),(d)))

#define lua_setfenv lua_setuservalue

#define lua_objlen lua_rawlen
#define lua_getfenv lua_getuservalue
#define lua_setfenv lua_setuservalue

#endif

