/*
*  Copyright 2015 The Luvit Authors. All Rights Reserved.
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
#define LUA_LIB
#include "luvi.h"

#include <windows.h>

static int lua_GetModuleFileName(lua_State *L)
{
  HMODULE handle = lua_touserdata(L, 1);
  TCHAR name[MAX_PATH + 1];
  DWORD ret = GetModuleFileName(handle, name, MAX_PATH + 1);
  if (ret > 0)
  {
    lua_pushstring(L, name);
    return 1;
  }
  lua_pushnil(L);
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_GetErrorString(lua_State *L)
{
  DWORD err = luaL_checkint(L, 1);
  LPTSTR lpMsgBuf = NULL;

  DWORD len = FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    err,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR)&lpMsgBuf,
    0, NULL);

  if (len) {
      if (len > 2) {
          // strip \r\n
          lpMsgBuf[len - 2] = '\0';
      }
      lua_pushstring(L, lpMsgBuf);
      LocalFree(lpMsgBuf);
      return 1;
  }
  lua_pushnil(L);
  lua_pushinteger(L, GetLastError());
  return 2;
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
