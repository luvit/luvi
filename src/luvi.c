/*
 *  Copyright 2014 The Luvit Authors. All Rights Reserved.
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

#include "./luvi.h"

LUALIB_API int luaopen_luvi(lua_State *L) {
  int i = 1;
  lua_newtable(L);
#ifdef LUVI_VERSION
  lua_pushstring(L, ""LUVI_VERSION"");
  lua_setfield(L, -2, "version");
#endif
  lua_newtable(L);
#ifdef WITH_OPENSSL
  lua_pushnumber(L, i++);
  lua_pushstring(L, "ssl");
  lua_settable(L, -3);
#endif
#ifdef WITH_ZLIB
  lua_pushnumber(L, i++);
  lua_pushstring(L, "zlib");
  lua_settable(L, -3);
#endif
#ifdef WITH_WINSVC
  lua_pushnumber(L, i++);
  lua_pushstring(L, "winsvc");
  lua_settable(L, -3);
#endif
  lua_setfield(L, -2, "options");
  return 1;
}
