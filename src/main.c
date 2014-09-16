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

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "uv.h"
#include "../luv/src/luv.c"
#include "luvi.c"

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

  // Store luvi module definition at preload.luvi
  lua_pushcfunction(L, luaopen_luvi);
  lua_setfield(L, -2, "luvi");

  // Expose command line arguments via global `args`
  lua_createtable (L, argc, 0);
  for (index = 0; index < argc; index++) {
    lua_pushstring(L, argv[index]);
    lua_rawseti(L, -2, index);
  }
  lua_setglobal(L, "args");

  // Load the init.lua script
  if (luaL_loadstring(L, "return require('init')(...)")) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Also expose arguments via (...) in main.lua
  for (index = 1; index < argc; index++) {
    lua_pushstring(L, argv[index]);
  }

  // Start the main script.
  if (lua_pcall(L, argc - 1, 1, 0)) {
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
