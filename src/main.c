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

#include "luvi.h"
#include "../deps/luv/src/luv.c"
#include "lenv.c"
#include "luvi.c"
#include "lminiz.c"

int main(int argc, char* argv[] ) {

  lua_State* L;
  int index;
  int res;

  // Hooks in libuv that need to be done in main.
  argv = uv_setup_args(argc, argv);

  // Create the lua state.
  L = luaL_newstate();
  if (L == NULL) {
    fprintf(stderr, "luaL_newstate has failed\n");
    return 1;
  }

  // Add in the lua standard libraries
  luaL_openlibs(L);

  // Get package.preload so we can store builtins in it.
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_remove(L, -2); // Remove package

  // Store uv module definition at preload.uv
  lua_pushcfunction(L, luaopen_luv);
  lua_setfield(L, -2, "uv");

  lua_pushcfunction(L, luaopen_env);
  lua_setfield(L, -2, "env");

  lua_pushcfunction(L, luaopen_miniz);
  lua_setfield(L, -2, "miniz");

  // Store luvi module definition at preload.luvi
  lua_pushcfunction(L, luaopen_luvi);
  lua_setfield(L, -2, "luvi");

#ifdef WITH_OPENSSL
  // Store luvi module definition at preload.openssl
  lua_pushcfunction(L, luaopen_openssl);
  lua_setfield(L, -2, "openssl");
#endif

#ifdef WITH_ZLIB
  // Store luvi module definition at preload.openssl
  lua_pushcfunction(L, luaopen_zlib);
  lua_setfield(L, -2, "zlib");
#endif

#ifdef WITH_WINSVC
  // Store luvi module definition at preload.openssl
  lua_pushcfunction(L, luaopen_winsvc);
  lua_setfield(L, -2, "winsvc");
  lua_pushcfunction(L, luaopen_winsvcaux);
  lua_setfield(L, -2, "winsvcaux");
#endif

  // Load the init.lua script
  if (luaL_loadstring(L, "return require('init')(...)")) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Pass the command-line arguments to init as a zero-indexed table
  lua_createtable (L, argc, 0);
  for (index = 0; index < argc; index++) {
    lua_pushstring(L, argv[index]);
    lua_rawseti(L, -2, index);
  }

  // Start the main script.
  if (lua_pcall(L, 1, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Use the return value from the script as process exit code.
  res = 0;
  if (lua_type(L, -1) == LUA_TNUMBER) {
    res = lua_tointeger(L, -1);
  }
  lua_close(L);
  return res;
}
