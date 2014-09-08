#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "uv.h"
#include "luv/src/luv.c"

int main(int argc, char* argv[] ) {

  lua_State *L;
  uv_loop_t *loop;

  argv = uv_setup_args(argc, argv);

  L = luaL_newstate();
  if (L == NULL) {
    fprintf(stderr, "luaL_newstate has failed\n");
    return 1;
  }

  luaL_openlibs(L);

  // int luaopen_luv (lua_State *L);

  loop = uv_default_loop();

  /* Load the file containing the script we are going to run */
  if (argc < 2) {
    printf("Usage: %s program.lua\n", argv[0]);
    return 1;
  }
  int status = luaL_loadfile(L, argv[1]);
  if (status) {
    /* If something went wrong, error message is at the top of */
    /* the stack */
    fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
    exit(1);
  }


  int result = lua_pcall(L, 0, LUA_MULTRET, 0);
  if (result) {
    fprintf(stderr, "Failed to run script: %s\n", lua_tostring(L, -1));
    exit(1);
  }
  // /* Run the main lua script */
  // if (luvit_run(L)) {
  //   printf("%s\n", lua_tostring(L, -1));
  //   lua_pop(L, 1);
  //   lua_close(L);
  //   return -1;
  // }

  lua_close(L);


  return 0;
}
