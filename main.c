#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "uv.h"
#include "luv/src/luv.c"

int main(int argc, char* argv[] ) {

  // Make sure a script was passed in.
  if (argc < 2) {
    printf("Usage: %s program.lua\n", argv[0]);
    return 1;
  }

  // Hooks in libuv that need to be done in main.
  argv = uv_setup_args(argc, argv);

  // Create the lua state.
  lua_State *L;
  L = luaL_newstate();
  if (L == NULL) {
    fprintf(stderr, "luaL_newstate has failed\n");
    return 1;
  }

  // Add in the lua standard libraries and libuv bindings
  luaL_openlibs(L);
  luaopen_luv(L);
  lua_setglobal(L, "uv");

  // Load the execute the input script.
  if (luaL_dofile(L, argv[1])) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return 1;
  }

  // Cleanup and exit.
  lua_close(L);
  return 0;
}
