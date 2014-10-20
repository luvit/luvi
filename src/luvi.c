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

#include "./luvi.h"

#include <string.h>
#include <stdlib.h>
#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#else
#include <unistd.h>
#include <errno.h>
#endif

#include "tinfl.c"

#ifdef __APPLE__
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#elif !defined(_MSC_VER)
extern char **environ;
#endif

static int lenv_keys(lua_State* L) {
#ifndef _WIN32

  unsigned int i, size = 0;
  while (environ[size]) size++;

  lua_createtable(L, size, 0);

  for (i = 0; i < size; ++i) {
    const char* var = environ[i];
    const char* s = strchr(var, '=');
    const size_t length = s ? s - var : strlen(var);

    lua_pushlstring(L, var, length);
    lua_rawseti(L, -2, i + 1);
  }

#else // _WIN32
  int i = 0;
  int show_hidden = 0;
  WCHAR* p;
  WCHAR* environment = GetEnvironmentStringsW();
  if (!environment) {
    return 0;
  }
  p = environment;
  if (lua_type(L, 1) == LUA_TBOOLEAN) {
    show_hidden = lua_toboolean(L, 1);
  }

  lua_newtable(L);
  while (*p) {
    char* utf8;
    size_t utf8_len;
    WCHAR* s;

    if (*p == L'=') {
      // If the key starts with '=' it is a hidden environment variable.
      if (show_hidden) {
        s = wcschr(p + 1, L'=');
      }
      else {
        // Skip it
        p += wcslen(p) + 1;
        continue;
      }
    }
    else {
      s = wcschr(p, L'=');
    }

    if (!s) {
      s = p + wcslen(p);
    }
    // Convert from WCHAR to UTF-8 encoded char
    utf8_len = WideCharToMultiByte(CP_UTF8, 0, p, s - p, NULL, 0, NULL, NULL);
    utf8 = malloc(utf8_len);
    WideCharToMultiByte(CP_UTF8, 0, p, s - p, utf8, utf8_len, NULL, NULL);

    lua_pushlstring(L, utf8, utf8_len);
    lua_rawseti(L, -2, ++i);

    free(utf8);

    p = s + wcslen(s) + 1;
  }
  FreeEnvironmentStringsW(environment);

#endif

  return 1;
}

static int lenv_get(lua_State* L) {
  const char* name = luaL_checkstring(L, 1);
#ifdef _WIN32
  char* value;
  WCHAR* wname;
  WCHAR* wvalue;
  size_t wsize, size, wname_size;

  // Convert UTF8 char* name to WCHAR* wname with null terminator
  wname_size = MultiByteToWideChar(CP_UTF8, 0, name, -1, NULL, 0);
  wname = malloc(wname_size * sizeof(WCHAR));
  if (!wname) {
    return luaL_error(L, "Problem allocating memory for environment variable.");
  }
  MultiByteToWideChar(CP_UTF8, 0, name, -1, wname, wname_size);

  // Check for the key
  wsize = GetEnvironmentVariableW(wname, NULL, 0);
  if (!wsize) {
    free(wname);
    return 0;
  }

  // Read the value
  wvalue = malloc(wsize * sizeof(WCHAR));
  if (!wvalue) {
    free(wname);
    return luaL_error(L, "Problem allocating memory for environment variable.");
  }
  GetEnvironmentVariableW(wname, wvalue, wsize);

  // Convert WCHAR* wvalue to UTF8 char* value
  size = WideCharToMultiByte(CP_UTF8, 0, wvalue, -1, NULL, 0, NULL, NULL);
  value = malloc(size);
  if (!value) {
    free(wname);
    free(wvalue);
    return luaL_error(L, "Problem allocating memory for environment variable.");
  }
  WideCharToMultiByte(CP_UTF8, 0, wvalue, -1, value, size, NULL, NULL);

  lua_pushlstring(L, value, size - 1);

  free(wname);
  free(wvalue);
  free(value);

#else
  lua_pushstring(L, getenv(name));
#endif
  return 1;
}

static int lenv_set(lua_State* L) {
  const char* name = luaL_checkstring(L, 1);
  const char* value = luaL_checkstring(L, 2);

#ifdef _WIN32
  WCHAR* wname;
  WCHAR* wvalue;
  size_t wname_size, wvalue_size;
  int r;
  // Convert UTF8 char* name to WCHAR* wname with null terminator
  wname_size = MultiByteToWideChar(CP_UTF8, 0, name, -1, NULL, 0);
  wname = malloc(wname_size * sizeof(WCHAR));
  if (!wname) return luaL_error(L, "Problem allocating memory for environment variable.");
  MultiByteToWideChar(CP_UTF8, 0, name, -1, wname, wname_size);

  // Convert UTF8 char* value to WCHAR* wvalue with null terminator
  wvalue_size = MultiByteToWideChar(CP_UTF8, 0, value, -1, NULL, 0);
  wvalue = malloc(wvalue_size * sizeof(WCHAR));
  if (!wvalue) {
    free(wname);
    return luaL_error(L, "Problem allocating memory for environment variable.");
  }
  MultiByteToWideChar(CP_UTF8, 0, value, -1, wvalue, wvalue_size);

  r = SetEnvironmentVariableW(wname, wvalue);

  free(wname);
  free(wvalue);
  if (r == 0) {
    return luaL_error(L, "Failed to set environment variable");
  }
#else
  int r = setenv(name, value, 1);
  if (r) {
    if (r == EINVAL) {
      return luaL_error(L, "EINVAL: Invalid name.");
    }
    return luaL_error(L, "ENOMEM: Insufficient memory to add a new variable to the environment.");
  }
#endif
  return 0;
}

static int lenv_unset(lua_State* L) {
  const char* name = luaL_checkstring(L, 1);

#ifdef __linux__
  if (unsetenv(name)) {
    if (errno == EINVAL)
      return luaL_error(L, "EINVAL: name contained an '=' character");
    return luaL_error(L, "unsetenv: Unknown error");
  }
#elif defined(_WIN32)
  WCHAR* wname;
  size_t wname_size;
  // Convert UTF8 char* name to WCHAR* wname with null terminator
  wname_size = MultiByteToWideChar(CP_UTF8, 0, name, -1, NULL, 0);
  wname = malloc(wname_size * sizeof(WCHAR));
  if (!wname) {
    return luaL_error(L, "Problem allocating memory for environment variable.");
  }
  MultiByteToWideChar(CP_UTF8, 0, name, -1, wname, wname_size);
  SetEnvironmentVariableW(wname, NULL);
#else
  unsetenv(name);
#endif
  return 0;
}

static const luaL_Reg lenv_f[] = {
  {"keys", lenv_keys},
  {"get", lenv_get},
  {"set", lenv_set},
  {"unset", lenv_unset},
  {NULL, NULL}
};

static int ltinfl(lua_State* L) {
  size_t in_len;
  const char* in_buf = luaL_checklstring(L, 1, &in_len);
  size_t out_len;
  int flags = luaL_optint(L, 2, 0);
  char* out_buf = tinfl_decompress_mem_to_heap(in_buf, in_len, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

LUALIB_API int luaopen_luvi(lua_State *L) {
  lua_newtable(L);
  luaL_newlib(L, lenv_f);
  lua_setfield(L, -2, "env");
  lua_pushcfunction(L, ltinfl);
  lua_setfield(L, -2, "inflate");
  return 1;
}
