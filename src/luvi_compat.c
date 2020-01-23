#define lstrlib_c
#define ltablib_c
#define lutf8lib_c

#include "luvi.h"
#include "compat-5.3.h"
#include "compat-5.3.c"

#include "lprefix.h"
#include "lstrlib.c"
#include "ltablib.c"
#include "lutf8lib.c"

#ifndef LUA_UTF8LIBNAME
#define LUA_UTF8LIBNAME	"utf8"
#endif
void luvi_openlibs(lua_State *L) {
  luaL_openlibs(L);
#if (LUA_VERSION_NUM!=503)
  {
    static luaL_Reg const funcs[] = {
      { "pack", str_pack },
      { "packsize", str_packsize },
      { "unpack", str_unpack },
      { NULL, NULL }
    };

    luaL_register(L, LUA_STRLIBNAME, funcs);
  }

  luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);
  lua_pop(L, 1);
#endif
}
