#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"

#include <windows.h>

static int lua_GetModuleFileName(lua_State *L)
{
  const char* handle = lua_tolstring(L, 1, NULL);
  TCHAR name[MAX_PATH + 1];
  DWORD ret = GetModuleFileName((HMODULE)handle, name, MAX_PATH + 1);
  if (ret > 0)
  {
    lua_pushstring(L, name);
    lua_pushnil(L);
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static int lua_GetErrorString(lua_State *L)
{
  DWORD err = luaL_checkint(L, 1);
  LPTSTR lpMsgBuf;

  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    err,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR)&lpMsgBuf,
    0, NULL);

  lua_pushstring(L, lpMsgBuf);
  LocalFree(lpMsgBuf);
  return 1;
}

static const luaL_Reg winsvcauxlib[] = {
    { "GetModuleFileName", lua_GetModuleFileName },
    { "GetErrorString", lua_GetErrorString },
    { NULL, NULL }
};

/*
** Open Windows Service Aux library
*/
LUALIB_API int luaopen_winsvcaux(lua_State *L) {
  luaL_register(L, "winsvcaux", winsvcauxlib);
  return 1;
}
