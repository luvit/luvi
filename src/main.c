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
#include "inflate.c"
#include "env.c"

extern const char* luaJIT_BC_init;

int main(int argc, char* argv[] ) {

  // Hooks in libuv that need to be done in main.
  argv = uv_setup_args(argc, argv);

  // Create the lua state.
  lua_State *L;
  L = luaL_newstate();
  if (L == NULL) {
    fprintf(stderr, "luaL_newstate has failed\n");
    return 1;
  }

  // Add in the lua standard libraries
  luaL_openlibs(L);

  // Expose the inflate function from tinfl.
  lua_pushcfunction(L, ltinfl);
  lua_setglobal(L, "inflate");

  lua_newtable (L);
  luaL_register(L, NULL, lenv_f);
  lua_setglobal(L, "env");

  // Expose libuv via global `uv`
  luaopen_luv(L);
  lua_setglobal(L, "uv");

  // Expose command line arguments via global `args`
  lua_createtable (L, argc, 0);
  for (int index = 0; index < argc; index++) {
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
  for (int index = 1; index < argc; index++) {
    lua_pushstring(L, argv[index]);
  }

  // Start the main script.
  if (lua_pcall(L, argc - 1, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Use the return value from the script as process exit code.
  int res = 0;
  if (lua_type(L, -1) == LUA_TNUMBER) {
    res = lua_tointeger(L, -1);
  }
  lua_close(L);
  return res;
}
