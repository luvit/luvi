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

  int luaopen_luv (lua_State *L);

  loop = uv_default_loop();

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
