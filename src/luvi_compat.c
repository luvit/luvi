#define lstrlib_c
#define ltablib_c
#define lutf8lib_c

#include "luvi.h"

#if (LUA_VERSION_NUM < 503)
#include "compat-5.3.h"
#include "compat-5.3.c"

#include "lprefix.h"
#include "lstrlib.c"
#include "ltablib.c"
#include "lutf8lib.c"
#endif

#if (LUA_VERSION_NUM == 501)
#ifndef LUA_UTF8LIBNAME
#define LUA_UTF8LIBNAME	"utf8"
#endif

#ifndef UTF8PATT_501
#define UTF8PATT_501 "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"
#endif
#endif

#ifdef WITH_PLAIN_LUA
#include "../deps/bit.c"
#endif

void luvi_openlibs(lua_State *L) {
  luaL_openlibs(L);
#if (LUA_VERSION_NUM < 503)
  {
    static luaL_Reg const funcs[] = {
      { "pack", str_pack },
      { "packsize", str_packsize },
      { "unpack", str_unpack },
      { NULL, NULL }
    };

#if (LUA_VERSION_NUM > 501)
    luaL_newlib(L, funcs);
#else
    luaL_register(L, LUA_STRLIBNAME, funcs);
#endif
  }
  lua_pop(L, 1);

  luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);

#if (LUA_VERSION_NUM == 501)
  lua_pushlstring(L, UTF8PATT_501, sizeof(UTF8PATT_501)/sizeof(char) - 1);
  lua_setfield(L, -2, "charpattern");
#endif
  lua_pop(L, 1);

#endif
}
