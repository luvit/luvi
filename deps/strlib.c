/* lstrlib.c come from https://github.com/keplerproject/lua-compat-5.3/blob/master/lstrlib.c */
#include "lstrlib.c"

void make_compat53_string(lua_State *L)
{
  luaL_Reg const funcs[] = {
    {"pack", str_pack},
    {"packsize", str_packsize},
    {"unpack", str_unpack},
    {NULL, NULL}
  };
  luaL_register(L, LUA_STRLIBNAME, funcs);
}
