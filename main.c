#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "uv.h"
#include "luv/src/luv.c"
#include "bundle.c"

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

  // Expose libuv via global `uv`
  luaopen_luv(L);
  lua_setglobal(L, "uv");

  // Expose bundle API via global `bundle`
  luaopen_bundle(L);
  lua_setglobal(L, "bundle");

  // Expose command line arguments via global `args`
  lua_createtable (L, argc, 0);
  for (int index = 0; index < argc; index++) {
    lua_pushstring(L, argv[index]);
    lua_rawseti(L, -2, index);
  }
  lua_setglobal(L, "args");

  // Compile main.lua from the bundle root.
  if (luaL_dostring(L, "return (function () "
    "local main = bundle.readfile('main.lua')\n"
    "if not main then error 'Missing main.lua in bundle' end\n"
    "return assert(loadstring(main, 'bundle:main.lua'))\n"
    "end)()\n"
  )) {
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
  int res = luaL_optinteger(L, -1, 0);
  lua_close(L);
  return res;
}
