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
#define LUA_LIB
#include "luvi.h"

#include <windows.h>
#include <winsvc.h>
#include <strsafe.h>

typedef struct {
  SERVICE_TABLE_ENTRY* svc_table;
  uv_async_t end_async_handle;
  int lua_cb_ref;
  BOOL return_code;
  DWORD error;
  lua_State* L;
} svc_dispatch_info;

typedef struct {
  int lua_cb_ref;
  uv_async_t async_handle;
  HANDLE block_end_event;
  DWORD dwControl;
  DWORD dwEventType;
  LPVOID lpEventData;
  LPVOID lpContext;
  DWORD return_code;
} svc_handler_block;

typedef struct _svc_baton {
  char* name;
  int lua_main_ref;
  uv_async_t svc_async_handle;
  HANDLE svc_end_event;
  SERVICE_STATUS_HANDLE status_handle;
  DWORD dwArgc;
  LPTSTR *lpszArgv;
  svc_handler_block block;
  struct _svc_baton* next;
  lua_State* L;
} svc_baton;

/* linked list of batons */
svc_baton* gBatons = NULL;

static int GetIntFromTable(lua_State *L, const char* name) {
  int result;
  lua_pushstring(L, name);
  lua_gettable(L, -2);  /* get table[key] */
  result = (int)lua_tointeger(L, -1);
  lua_pop(L, 1);  /* remove number */
  return result;
}

static const char* GetStringFromTable(lua_State *L, const char* name) {
  const char* result;
  lua_pushstring(L, name);
  lua_gettable(L, -2);  /* get table[key] */
  result = lua_tostring(L, -1);
  lua_pop(L, 1);  /* remove string */
  return result;
}

DWORD WINAPI HandlerEx(_In_  DWORD dwControl, _In_  DWORD dwEventType, _In_  LPVOID lpEventData, _In_  LPVOID lpContext) {
  svc_baton *baton = lpContext;
  baton->block.dwControl = dwControl;
  baton->block.dwEventType = dwEventType;
  baton->block.lpEventData = lpEventData;
  baton->block.lpContext = lpContext;

  ResetEvent(baton->block.block_end_event);
  uv_async_send(&baton->block.async_handle);
  WaitForSingleObject(baton->block.block_end_event, INFINITE);
  return baton->block.return_code;
}

static void svchandler_cb(uv_async_t* handle) {
  svc_baton* baton = handle->data;
  lua_State* L = baton->L;

  lua_pushstring(L, "winsvc_error_cb");
  lua_gettable(L, LUA_REGISTRYINDEX);
  lua_rawgeti(L, LUA_REGISTRYINDEX, baton->block.lua_cb_ref);
  lua_pushinteger(L, baton->block.dwControl);
  lua_pushinteger(L, baton->block.dwEventType);
  lua_pushlightuserdata(L, baton->block.lpEventData);
  lua_pushlightuserdata(L, baton->block.lpContext);
  if (lua_pcall(L, 4, 1, -6) == 0) {
    baton->block.return_code = luaL_checkint(L, -1);
  }
  else {
    baton->block.return_code = ERROR;
  }
  SetEvent(baton->block.block_end_event);
}

static void svcmain_cb(uv_async_t* handle) {
  svc_baton* baton = handle->data;
  lua_State* L = baton->L;

  lua_pushstring(L, "winsvc_error_cb");
  lua_gettable(L, LUA_REGISTRYINDEX);
  lua_rawgeti(L, LUA_REGISTRYINDEX, baton->lua_main_ref);
  lua_newtable(L);
  for (unsigned int i = 0; i < baton->dwArgc; i++) {
    lua_pushnumber(L, i + 1);   /* Push the table index */
    lua_pushstring(L, baton->lpszArgv[i]); /* Push the cell value */
    lua_rawset(L, -3);      /* Stores the pair in the table */
  }
  lua_pushlightuserdata(L, baton);
  lua_pcall(L, 2, 0, -4);
}

static svc_baton* svc_create_baton(lua_State* L, const char* name, int main_ref, int cb_ref) {
  luv_ctx_t* ctx = luv_context(L);
  uv_loop_t* loop = ctx->loop;
  svc_baton* baton = LocalAlloc(LPTR, sizeof(svc_baton));
  baton->lua_main_ref = main_ref;
  baton->block.lua_cb_ref = cb_ref;
  baton->name = _strdup(name);
  uv_async_init(loop, &baton->svc_async_handle, svcmain_cb);
  uv_async_init(loop, &baton->block.async_handle, svchandler_cb);
  baton->svc_async_handle.data = baton;
  baton->block.async_handle.data = baton;
  baton->svc_end_event = CreateEvent(NULL, TRUE, FALSE, NULL);
  baton->block.block_end_event = CreateEvent(NULL, TRUE, FALSE, NULL);
  baton->next = NULL;
  baton->L = ctx->L;
  return baton;
}

static void svc_destroy_baton(lua_State* L, svc_baton* baton) {
  luaL_unref(L, LUA_REGISTRYINDEX, baton->block.lua_cb_ref);
  luaL_unref(L, LUA_REGISTRYINDEX, baton->lua_main_ref);
  free(baton->name);
  uv_close((uv_handle_t*)&baton->svc_async_handle, NULL);
  uv_close((uv_handle_t*)&baton->block.async_handle, NULL);
  CloseHandle(baton->svc_end_event);
  CloseHandle(baton->block.block_end_event);
  LocalFree(baton);
}

static svc_baton* find_baton(const char* name) {
  svc_baton* it = gBatons;
  while (it != NULL) {
    if (strcmp(it->name, name) == 0) {
      break;
    }
    it = it->next;
  }

  return it;
}


VOID WINAPI ServiceMain(_In_  DWORD dwArgc, _In_  LPTSTR *lpszArgv) {
  svc_baton *baton = find_baton(lpszArgv[0]);
  baton->status_handle = RegisterServiceCtrlHandlerEx(baton->name, HandlerEx, baton);
  baton->dwArgc = dwArgc;
  baton->lpszArgv = lpszArgv;

  uv_async_send(&baton->svc_async_handle);
  WaitForSingleObject(baton->svc_end_event, INFINITE);
}

static int lua_GetStatusHandleFromContext(lua_State *L) {
  svc_baton* baton = lua_touserdata(L, 1);
  lua_pushlightuserdata(L, baton->status_handle);
  return 1;
}

static int lua_EndService(lua_State *L) {
  svc_baton* baton = lua_touserdata(L, 1);
  SetEvent(baton->svc_end_event);
  return 0;
}

static int table_to_ServiceStatus(lua_State *L, SERVICE_STATUS *status) {
  memset(status, 0, sizeof(SERVICE_STATUS));
  if (lua_isnil(L, -1)) {
    return 0;
  }
  if (!lua_istable(L, -1)) {
    return luaL_error(L, "table expected");
  }

  status->dwCheckPoint = GetIntFromTable(L, "dwCheckPoint");
  status->dwControlsAccepted = GetIntFromTable(L, "dwControlsAccepted");
  status->dwCurrentState = GetIntFromTable(L, "dwCurrentState");
  status->dwServiceSpecificExitCode = GetIntFromTable(L, "dwServiceSpecificExitCode");
  status->dwServiceType = GetIntFromTable(L, "dwServiceType");
  status->dwWaitHint = GetIntFromTable(L, "dwWaitHint");
  status->dwWin32ExitCode = GetIntFromTable(L, "dwWin32ExitCode");

  return 0;
}

static void ServiceStatus_to_table(lua_State *L, SERVICE_STATUS *status) {
  lua_newtable(L);
  lua_pushstring(L, "dwCheckPoint");
  lua_pushinteger(L, status->dwCheckPoint);
  lua_settable(L, -3);
  lua_pushstring(L, "dwControlsAccepted");
  lua_pushinteger(L, status->dwControlsAccepted);
  lua_settable(L, -3);
  lua_pushstring(L, "dwCurrentState");
  lua_pushinteger(L, status->dwCurrentState);
  lua_settable(L, -3);
  lua_pushstring(L, "dwServiceSpecificExitCode");
  lua_pushinteger(L, status->dwServiceSpecificExitCode);
  lua_settable(L, -3);
  lua_pushstring(L, "dwServiceType");
  lua_pushinteger(L, status->dwServiceType);
  lua_settable(L, -3);
  lua_pushstring(L, "dwWaitHint");
  lua_pushinteger(L, status->dwWaitHint);
  lua_settable(L, -3);
  lua_pushstring(L, "dwWin32ExitCode");
  lua_pushinteger(L, status->dwWin32ExitCode);
  lua_settable(L, -3);
}

static int lua_SetServiceStatus(lua_State *L) {
  SERVICE_STATUS status;
  SERVICE_STATUS_HANDLE SvcStatusHandler = lua_touserdata(L, 1);
  int ret = table_to_ServiceStatus(L, &status);
  if (ret != 0) {
    return ret;
  }

  BOOL set = SetServiceStatus(SvcStatusHandler, (LPSERVICE_STATUS)&status);
  lua_pushboolean(L, set);
  if (set)
    return 1;
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_ControlService(lua_State *L) {
  SERVICE_STATUS status;
  SC_HANDLE SvcCtrlHandler = lua_touserdata(L, 1);
  DWORD dwControl = luaL_checkint(L, 2);

  BOOL set = ControlService(SvcCtrlHandler, dwControl, (LPSERVICE_STATUS)&status);
  lua_pushboolean(L, set);
  ServiceStatus_to_table(L, &status);
  if (set)
    return 2;
  lua_pushinteger(L, GetLastError());
  return 3;
}

static int lua_StartService(lua_State *L) {
  SC_HANDLE SvcCtrlHandler = lua_touserdata(L, 1);
  size_t numargs = 0;
  LPCSTR *args = NULL;
  if (!(lua_isnil(L, 2) || lua_istable(L, 2))) {
    return luaL_error(L, "table (array) or nil expected");
  }

  if (lua_istable(L, 2)) {
    lua_pushnil(L);
    numargs = lua_rawlen(L, 2);
    if (numargs) {
      args = LocalAlloc(LPTR, sizeof(LPCSTR) * numargs);
    }
    size_t i = 0;
    while (lua_next(L, 2)) {
      /* uses 'key' (at index -2) and 'value' (at index -1) */
      args[i] = luaL_checkstring(L, -1);
      i++;
    }
    lua_pop(L, 2);
  }

  BOOL set = StartService(SvcCtrlHandler, (DWORD)numargs, args);
  lua_pushboolean(L, set);
  if (set)
    return 1;
  lua_pushinteger(L, GetLastError());
  return 2;
}

static void svcdispatcher_end_cb(uv_async_t* handle) {
  svc_dispatch_info *info = (svc_dispatch_info*)handle->data;
  lua_State* L = info->L;

  /* Cleanup baton linked list */
  svc_baton *svc_baton_it = gBatons;
  while (svc_baton_it != NULL) {
    svc_baton *old = svc_baton_it;
    svc_baton_it = svc_baton_it->next;
    svc_destroy_baton(L, old);
  }

  uv_close((uv_handle_t*)&info->end_async_handle, NULL);
  gBatons = NULL;

  lua_rawgeti(L, LUA_REGISTRYINDEX, info->lua_cb_ref);
  lua_pushboolean(L, info->return_code);
  if (info->return_code) {
    lua_pushnil(L);
  }
  else {
    lua_pushinteger(L, info->error);
  }
  lua_call(L, 2, 0);
  luaL_unref(L, LUA_REGISTRYINDEX, info->lua_cb_ref);

  LocalFree(info->svc_table);
  LocalFree(info);
}

DWORD StartServiceCtrlDispatcherThread(LPVOID lpThreadParam) {
  svc_dispatch_info *info = (svc_dispatch_info*)lpThreadParam;
  info->return_code = StartServiceCtrlDispatcher(info->svc_table);
  if (!info->return_code) {
    info->error = GetLastError();
  }
  info->end_async_handle.data = info;
  uv_async_send(&info->end_async_handle);
  return 0;
}

static int lua_SpawnServiceCtrlDispatcher(lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  luaL_checktype(L, 3, LUA_TFUNCTION);
  if (gBatons) {
    return luaL_error(L, "ServiceCtrlDispatcher is already running");
  }

  /* structure allocation/setup */
  BOOL ret = FALSE;
  size_t len = 0;
  svc_dispatch_info *info = LocalAlloc(LPTR, sizeof(svc_dispatch_info));
  info->L = luv_state(L);
  uv_async_init(luv_loop(L), &info->end_async_handle, svcdispatcher_end_cb);
  svc_baton** baton_pp = &gBatons;

  /* Convert the table to a service table and setup the baton table */
  lua_pushnil(L);  /* first key */
  while (lua_next(L, 1) != 0) {
    /* uses 'key' (at index -2) and 'value' (at index -1) */
    const char* name = luaL_checkstring(L, -2);

    luaL_checktype(L, -1, LUA_TTABLE);
    lua_pushvalue(L, -1);
    lua_pushnil(L);
    lua_next(L, -2);
    luaL_checktype(L, -1, LUA_TFUNCTION);
    lua_pushvalue(L, -1);
    int main_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    lua_next(L, -2);
    luaL_checktype(L, -1, LUA_TFUNCTION);
    lua_pushvalue(L, -1);
    int cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 3);

    *baton_pp = svc_create_baton(L, _strdup(name), main_ref, cb_ref);
    baton_pp = &(*baton_pp)->next;

    // count the entries
    ++len;

    /* removes 'value'; keeps 'key' for next iteration */
    lua_pop(L, 1);
  }

  if (len == 0) {
    return luaL_error(L, "Service Dispatch Table is empty");
  }

  lua_pushvalue(L, 2);
  info->lua_cb_ref = luaL_ref(L, LUA_REGISTRYINDEX);

  /* store the error cb in the registry */
  lua_pushstring(L, "winsvc_error_cb");
  lua_pushvalue(L, 3);
  lua_settable(L, LUA_REGISTRYINDEX);

  /* Create Windows Service Entry Table */
  info->svc_table = LocalAlloc(LPTR, sizeof(SERVICE_TABLE_ENTRY) * (len + 1));
  svc_baton* baton_it = gBatons;
  SERVICE_TABLE_ENTRY* entry_it = info->svc_table;
  while(baton_it) {
    entry_it->lpServiceName = baton_it->name;
    entry_it->lpServiceProc = ServiceMain;
    baton_it = baton_it->next;
    ++entry_it;
  }


  /* Start */
  HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)&StartServiceCtrlDispatcherThread, info, 0, NULL);
  ret = thread != NULL;

  lua_pushboolean(L, ret);
  if (ret)
    return 1;
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_OpenSCManager(lua_State *L) {
  const char* machinename = lua_tostring(L, 1);
  const char* databasename = lua_tostring(L, 2);
  DWORD access = luaL_checkint(L, 3);
  SC_HANDLE h = OpenSCManager(machinename, databasename, access);
  if (h != NULL) {
    lua_pushlightuserdata(L, h);
    return 1;
  }
  lua_pushnil(L);
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_OpenService(lua_State *L)
{
  SC_HANDLE hSCManager = lua_touserdata(L, 1);
  const char* servicename = luaL_checkstring(L, 2);
  DWORD access = luaL_checkint(L, 3);
  SC_HANDLE h = OpenService(hSCManager, servicename, access);
  if (h != NULL) {
    lua_pushlightuserdata(L, h);
    return 1;
  }
  lua_pushnil(L);
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_CreateService(lua_State *L) {
  SC_HANDLE hSCManager = lua_touserdata(L, 1);
  const char* servicename = luaL_checkstring(L, 2);
  const char* displayname = luaL_checkstring(L, 3);
  DWORD access = luaL_checkint(L, 4);
  DWORD servicetype = luaL_checkint(L, 5);
  DWORD starttype = luaL_checkint(L, 6);
  DWORD errorcontrol = luaL_checkint(L, 7);
  const char* pathname = luaL_checkstring(L, 8);
  const char* loadordergroup = lua_tostring(L, 9);
  DWORD tagid = 0;
  DWORD *tagidp = loadordergroup?&tagid:NULL;
  const char* deps = lua_tostring(L, 10);
  const char* username = lua_tostring(L, 11);
  const char* password = lua_tostring(L, 12);


  SC_HANDLE h = CreateService(hSCManager, servicename, displayname, access, servicetype, starttype, errorcontrol, pathname, loadordergroup, tagidp, deps, username, password);
  if (h != NULL) {
    lua_pushlightuserdata(L, h);
    lua_pushinteger(L, tagid);
    return 2;
  }
  lua_pushnil(L);
  lua_pushnil(L);
  lua_pushinteger(L, GetLastError());
  return 3;
}

static int lua_CloseServiceHandle(lua_State *L) {
  SC_HANDLE h = lua_touserdata(L, 1);
  BOOL ret = CloseServiceHandle(h);
  lua_pushboolean(L, ret);
  if (ret)
    return 1;
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_DeleteService(lua_State *L) {
  SC_HANDLE h = lua_touserdata(L, 1);
  BOOL ret = DeleteService(h);
  lua_pushboolean(L, ret);
  if (ret)
    return 1;
  lua_pushinteger(L, GetLastError());
  return 2;
}

static int lua_ChangeServiceConfig2(lua_State *L) {
  SC_HANDLE h = lua_touserdata(L, 1);
  DWORD dwInfoLevel = luaL_checkint(L, 2);
  union {
    SERVICE_DESCRIPTION description;
    SERVICE_FAILURE_ACTIONS failure_actions;
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
    SERVICE_DELAYED_AUTO_START_INFO autostart;
    SERVICE_FAILURE_ACTIONS_FLAG failure_actions_flag;
    SERVICE_PRESHUTDOWN_INFO preshutdown_info;
    SERVICE_REQUIRED_PRIVILEGES_INFO privileges_info;
    SERVICE_SID_INFO sid_info;
#endif
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN7
    SERVICE_PREFERRED_NODE_INFO preferred_node;
#endif
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN8LUE
    SERVICE_LAUNCH_PROTECTED_INFO protected_info;
#endif
  } info, *infop = &info;
  memset(infop, 0, sizeof(info));
  luaL_checktype(L, 3, LUA_TTABLE);

  switch (dwInfoLevel)
  {
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
  case SERVICE_CONFIG_DELAYED_AUTO_START_INFO:
    info.autostart.fDelayedAutostart = GetIntFromTable(L, "fDelayedAutostart");
    break;
#endif
  case SERVICE_CONFIG_DESCRIPTION:
    info.description.lpDescription = (char*)GetStringFromTable(L, "lpDescription");
    break;
  case SERVICE_CONFIG_FAILURE_ACTIONS:
    info.failure_actions.dwResetPeriod = GetIntFromTable(L, "dwResetPeriod");
    info.failure_actions.lpRebootMsg = (char*)GetStringFromTable(L, "lpRebootMsg");
    lua_pushstring(L, "lpsaActions");
    lua_gettable(L, -2);
    if (lua_type(L, -1) == LUA_TTABLE) {
      info.failure_actions.cActions = lua_objlen(L, -1);
      if (info.failure_actions.cActions) {
        info.failure_actions.lpsaActions = LocalAlloc(LPTR, sizeof(SC_ACTION) * info.failure_actions.cActions);
      }
      DWORD i = 0;
      while (i < info.failure_actions.cActions) {
        lua_rawgeti(L, -1, i+1);
        luaL_checktype(L, -1, LUA_TTABLE);
        info.failure_actions.lpsaActions[i].Delay = GetIntFromTable(L, "Delay");
        info.failure_actions.lpsaActions[i].Type = GetIntFromTable(L, "Type");
        lua_pop(L, 1);
        ++i;
      }
      lua_pop(L, 1);
    }
    break;
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
  case SERVICE_CONFIG_FAILURE_ACTIONS_FLAG:
    info.failure_actions_flag.fFailureActionsOnNonCrashFailures = GetIntFromTable(L, "fFailureActionsOnNonCrashFailures");
    break;
#endif
#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN7
  case SERVICE_CONFIG_PREFERRED_NODE:
    info.preferred_node.usPreferredNode = GetIntFromTable(L, "usPreferredNode");
    info.preferred_node.fDelete = GetIntFromTable(L, "fDelete");
    break;
#endif
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
  case SERVICE_CONFIG_PRESHUTDOWN_INFO:
    info.preshutdown_info.dwPreshutdownTimeout = GetIntFromTable(L, "dwPreshutdownTimeout");
    break;
  case SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO:
    info.privileges_info.pmszRequiredPrivileges = (char*)GetStringFromTable(L, "pmszRequiredPrivileges");
    break;
  case SERVICE_CONFIG_SERVICE_SID_INFO:
    info.sid_info.dwServiceSidType = GetIntFromTable(L, "dwServiceSidType");
    break;
#endif
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN8LUE
  /* case SERVICE_CONFIG_TRIGGER_INFO unsupported by ANSI version of ChangeServiceConfig2 */
  case SERVICE_CONFIG_LAUNCH_PROTECTED:
    info.protected_info.dwLaunchProtected = GetIntFromTable(L, "dwLaunchProtected");
    break;
#endif
  default:
    infop = NULL;
    break;
  }

  BOOL ret = ChangeServiceConfig2(h, dwInfoLevel, infop);

  switch (dwInfoLevel)
  {
  case SERVICE_CONFIG_FAILURE_ACTIONS:
    LocalFree(info.failure_actions.lpsaActions);
    break;
  default:
    break;
  }
  lua_pushboolean(L, ret);
  if (ret) {
    lua_pushnil(L);
  }
  else {
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static const luaL_Reg winsvclib[] = {
    { "GetStatusHandleFromContext", lua_GetStatusHandleFromContext },
    { "EndService", lua_EndService },
    { "SetServiceStatus", lua_SetServiceStatus },
    { "SpawnServiceCtrlDispatcher", lua_SpawnServiceCtrlDispatcher },
    { "OpenSCManager", lua_OpenSCManager },
    { "CloseServiceHandle", lua_CloseServiceHandle },
    { "CreateService", lua_CreateService },
    { "OpenService", lua_OpenService },
    { "DeleteService", lua_DeleteService },
    { "StartService", lua_StartService },
    { "ControlService", lua_ControlService },
    { "ChangeServiceConfig2", lua_ChangeServiceConfig2 },
    { NULL, NULL }
};

#define SETLITERAL(v) (lua_pushliteral(L, #v), lua_pushliteral(L, v), lua_settable(L, -3))
#define SETINT(v) (lua_pushliteral(L, #v), lua_pushinteger(L, v), lua_settable(L, -3))

/*
** Open Windows service library
*/
LUALIB_API int luaopen_winsvc(lua_State *L) {
  luaL_register(L, "winsvc", winsvclib);

  // Some Windows Defines
  SETINT(ERROR);
  SETINT(ERROR_CALL_NOT_IMPLEMENTED);
  SETINT(NO_ERROR);

  // Service defines from winnt.h
  SETINT(SERVICE_KERNEL_DRIVER);
  SETINT(SERVICE_FILE_SYSTEM_DRIVER);
  SETINT(SERVICE_ADAPTER);
  SETINT(SERVICE_RECOGNIZER_DRIVER);
  SETINT(SERVICE_DRIVER);
  SETINT(SERVICE_WIN32_OWN_PROCESS);
  SETINT(SERVICE_WIN32_SHARE_PROCESS);
  SETINT(SERVICE_WIN32);
  SETINT(SERVICE_INTERACTIVE_PROCESS);
  SETINT(SERVICE_TYPE_ALL);

  SETINT(SERVICE_BOOT_START);
  SETINT(SERVICE_SYSTEM_START);
  SETINT(SERVICE_AUTO_START);
  SETINT(SERVICE_DEMAND_START);
  SETINT(SERVICE_DISABLED);

  SETINT(SERVICE_ERROR_IGNORE);
  SETINT(SERVICE_ERROR_NORMAL);
  SETINT(SERVICE_ERROR_SEVERE);
  SETINT(SERVICE_ERROR_CRITICAL);

  SETINT(DELETE);
  SETINT(READ_CONTROL);
  SETINT(WRITE_DAC);
  SETINT(WRITE_OWNER);
  SETINT(SYNCHRONIZE);

  // Service Defines
  SETLITERAL(SERVICES_ACTIVE_DATABASE);
  SETLITERAL(SERVICES_FAILED_DATABASE);
  SETINT(SC_GROUP_IDENTIFIER);

  SETINT(SERVICE_NO_CHANGE);

  SETINT(SERVICE_ACTIVE);
  SETINT(SERVICE_INACTIVE);
  SETINT(SERVICE_STATE_ALL);

  SETINT(SERVICE_CONTROL_STOP);
  SETINT(SERVICE_CONTROL_PAUSE);
  SETINT(SERVICE_CONTROL_CONTINUE);
  SETINT(SERVICE_CONTROL_INTERROGATE);
  SETINT(SERVICE_CONTROL_SHUTDOWN);
  SETINT(SERVICE_CONTROL_PARAMCHANGE);
  SETINT(SERVICE_CONTROL_NETBINDADD);
  SETINT(SERVICE_CONTROL_NETBINDREMOVE);
  SETINT(SERVICE_CONTROL_NETBINDENABLE);
  SETINT(SERVICE_CONTROL_NETBINDDISABLE);
  SETINT(SERVICE_CONTROL_DEVICEEVENT);
  SETINT(SERVICE_CONTROL_HARDWAREPROFILECHANGE);
  SETINT(SERVICE_CONTROL_POWEREVENT);
  SETINT(SERVICE_CONTROL_SESSIONCHANGE);
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
  SETINT(SERVICE_CONTROL_PRESHUTDOWN);
  SETINT(SERVICE_CONTROL_TIMECHANGE);
  SETINT(SERVICE_CONTROL_TRIGGEREVENT);
#endif

  SETINT(SERVICE_STOPPED);
  SETINT(SERVICE_START_PENDING);
  SETINT(SERVICE_STOP_PENDING);
  SETINT(SERVICE_RUNNING);
  SETINT(SERVICE_CONTINUE_PENDING);
  SETINT(SERVICE_PAUSE_PENDING);
  SETINT(SERVICE_PAUSED);

  SETINT(SERVICE_ACCEPT_STOP);
  SETINT(SERVICE_ACCEPT_PAUSE_CONTINUE);
  SETINT(SERVICE_ACCEPT_SHUTDOWN);
  SETINT(SERVICE_ACCEPT_PARAMCHANGE);
  SETINT(SERVICE_ACCEPT_NETBINDCHANGE);
  SETINT(SERVICE_ACCEPT_HARDWAREPROFILECHANGE);
  SETINT(SERVICE_ACCEPT_POWEREVENT);
  SETINT(SERVICE_ACCEPT_SESSIONCHANGE);
#if defined(_WINNT_VER) && _WINNT_VER >= _WIN32_WINNT_WIN6
  SETINT(SERVICE_ACCEPT_PRESHUTDOWN);
  SETINT(SERVICE_ACCEPT_TIMECHANGE);
  SETINT(SERVICE_ACCEPT_TRIGGEREVENT);
#endif

  SETINT(SC_MANAGER_CONNECT);
  SETINT(SC_MANAGER_CREATE_SERVICE);
  SETINT(SC_MANAGER_ENUMERATE_SERVICE);
  SETINT(SC_MANAGER_LOCK);
  SETINT(SC_MANAGER_QUERY_LOCK_STATUS);
  SETINT(SC_MANAGER_MODIFY_BOOT_CONFIG);
  SETINT(SC_MANAGER_ALL_ACCESS);

  SETINT(SERVICE_QUERY_CONFIG);
  SETINT(SERVICE_CHANGE_CONFIG);
  SETINT(SERVICE_QUERY_STATUS);
  SETINT(SERVICE_ENUMERATE_DEPENDENTS);
  SETINT(SERVICE_START);
  SETINT(SERVICE_STOP);
  SETINT(SERVICE_PAUSE_CONTINUE);
  SETINT(SERVICE_INTERROGATE);
  SETINT(SERVICE_USER_DEFINED_CONTROL);
  SETINT(SERVICE_ALL_ACCESS);

  SETINT(SERVICE_RUNS_IN_SYSTEM_PROCESS);

  SETINT(SERVICE_CONFIG_DESCRIPTION);
  SETINT(SERVICE_CONFIG_FAILURE_ACTIONS);
#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN6
  SETINT(SERVICE_CONFIG_DELAYED_AUTO_START_INFO);
  SETINT(SERVICE_CONFIG_FAILURE_ACTIONS_FLAG);
  SETINT(SERVICE_CONFIG_SERVICE_SID_INFO);
  SETINT(SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO);
  SETINT(SERVICE_CONFIG_PRESHUTDOWN_INFO);
  SETINT(SERVICE_CONFIG_TRIGGER_INFO);
  SETINT(SERVICE_CONFIG_PREFERRED_NODE);
  // reserved                                     10
  // reserved                                     11
  SETINT(SERVICE_CONFIG_LAUNCH_PROTECTED);

  SETINT(SERVICE_NOTIFY_STATUS_CHANGE_1);
  SETINT(SERVICE_NOTIFY_STATUS_CHANGE_2);
  SETINT(SERVICE_NOTIFY_STATUS_CHANGE);

  SETINT(SERVICE_NOTIFY_STOPPED);
  SETINT(SERVICE_NOTIFY_START_PENDING);
  SETINT(SERVICE_NOTIFY_STOP_PENDING);
  SETINT(SERVICE_NOTIFY_RUNNING);
  SETINT(SERVICE_NOTIFY_CONTINUE_PENDING);
  SETINT(SERVICE_NOTIFY_PAUSE_PENDING);
  SETINT(SERVICE_NOTIFY_PAUSED);
  SETINT(SERVICE_NOTIFY_CREATED);
  SETINT(SERVICE_NOTIFY_DELETED);
  SETINT(SERVICE_NOTIFY_DELETE_PENDING);

  SETINT(SERVICE_STOP_REASON_FLAG_MIN);
  SETINT(SERVICE_STOP_REASON_FLAG_UNPLANNED);
  SETINT(SERVICE_STOP_REASON_FLAG_CUSTOM);
  SETINT(SERVICE_STOP_REASON_FLAG_PLANNED);
  SETINT(SERVICE_STOP_REASON_FLAG_MAX);

  SETINT(SERVICE_STOP_REASON_MAJOR_MIN);
  SETINT(SERVICE_STOP_REASON_MAJOR_OTHER);
  SETINT(SERVICE_STOP_REASON_MAJOR_HARDWARE);
  SETINT(SERVICE_STOP_REASON_MAJOR_OPERATINGSYSTEM);
  SETINT(SERVICE_STOP_REASON_MAJOR_SOFTWARE);
  SETINT(SERVICE_STOP_REASON_MAJOR_APPLICATION);
  SETINT(SERVICE_STOP_REASON_MAJOR_NONE);
  SETINT(SERVICE_STOP_REASON_MAJOR_MAX);
  SETINT(SERVICE_STOP_REASON_MAJOR_MIN_CUSTOM);
  SETINT(SERVICE_STOP_REASON_MAJOR_MAX_CUSTOM);

  SETINT(SERVICE_STOP_REASON_MINOR_MIN);
  SETINT(SERVICE_STOP_REASON_MINOR_OTHER);
  SETINT(SERVICE_STOP_REASON_MINOR_MAINTENANCE);
  SETINT(SERVICE_STOP_REASON_MINOR_INSTALLATION);
  SETINT(SERVICE_STOP_REASON_MINOR_UPGRADE);
  SETINT(SERVICE_STOP_REASON_MINOR_RECONFIG);
  SETINT(SERVICE_STOP_REASON_MINOR_HUNG);
  SETINT(SERVICE_STOP_REASON_MINOR_UNSTABLE);
  SETINT(SERVICE_STOP_REASON_MINOR_DISK);
  SETINT(SERVICE_STOP_REASON_MINOR_NETWORKCARD);
  SETINT(SERVICE_STOP_REASON_MINOR_ENVIRONMENT);
  SETINT(SERVICE_STOP_REASON_MINOR_HARDWARE_DRIVER);
  SETINT(SERVICE_STOP_REASON_MINOR_OTHERDRIVER);
  SETINT(SERVICE_STOP_REASON_MINOR_SERVICEPACK);
  SETINT(SERVICE_STOP_REASON_MINOR_SOFTWARE_UPDATE);
  SETINT(SERVICE_STOP_REASON_MINOR_SECURITYFIX);
  SETINT(SERVICE_STOP_REASON_MINOR_SECURITY);
  SETINT(SERVICE_STOP_REASON_MINOR_NETWORK_CONNECTIVITY);
  SETINT(SERVICE_STOP_REASON_MINOR_WMI);
  SETINT(SERVICE_STOP_REASON_MINOR_SERVICEPACK_UNINSTALL);
  SETINT(SERVICE_STOP_REASON_MINOR_SOFTWARE_UPDATE_UNINSTALL);
  SETINT(SERVICE_STOP_REASON_MINOR_SECURITYFIX_UNINSTALL);
  SETINT(SERVICE_STOP_REASON_MINOR_MMC);
  SETINT(SERVICE_STOP_REASON_MINOR_NONE);
  SETINT(SERVICE_STOP_REASON_MINOR_MAX);
  SETINT(SERVICE_STOP_REASON_MINOR_MIN_CUSTOM);
  SETINT(SERVICE_STOP_REASON_MINOR_MAX_CUSTOM);
#endif

#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN6
  SETINT(SERVICE_CONTROL_STATUS_REASON_INFO);

  SETINT(SERVICE_SID_TYPE_NONE);
  SETINT(SERVICE_SID_TYPE_UNRESTRICTED);
  SETINT(SERVICE_SID_TYPE_RESTRICTED);
#endif

#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN7
  SETINT(SERVICE_TRIGGER_TYPE_DEVICE_INTERFACE_ARRIVAL);
  SETINT(SERVICE_TRIGGER_TYPE_IP_ADDRESS_AVAILABILITY);
  SETINT(SERVICE_TRIGGER_TYPE_DOMAIN_JOIN);
  SETINT(SERVICE_TRIGGER_TYPE_FIREWALL_PORT_EVENT);
  SETINT(SERVICE_TRIGGER_TYPE_GROUP_POLICY);
  SETINT(SERVICE_TRIGGER_TYPE_NETWORK_ENDPOINT);
  SETINT(SERVICE_TRIGGER_TYPE_CUSTOM_SYSTEM_STATE_CHANGE);
  SETINT(SERVICE_TRIGGER_TYPE_CUSTOM);

  SETINT(SERVICE_TRIGGER_DATA_TYPE_BINARY);
  SETINT(SERVICE_TRIGGER_DATA_TYPE_STRING);
  SETINT(SERVICE_TRIGGER_DATA_TYPE_LEVEL);
  SETINT(SERVICE_TRIGGER_DATA_TYPE_KEYWORD_ANY);
  SETINT(SERVICE_TRIGGER_DATA_TYPE_KEYWORD_ALL);
#endif

#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN7
  SETINT(SERVICE_START_REASON_DEMAND);
  SETINT(SERVICE_START_REASON_AUTO);
  SETINT(SERVICE_START_REASON_TRIGGER);
  SETINT(SERVICE_START_REASON_RESTART_ON_FAILURE);
  SETINT(SERVICE_START_REASON_DELAYEDAUTO);

  SETINT(SERVICE_DYNAMIC_INFORMATION_LEVEL_START_REASON);
#endif

#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN8LUE
  SETINT(SERVICE_LAUNCH_PROTECTED_NONE);
  SETINT(SERVICE_LAUNCH_PROTECTED_WINDOWS);
  SETINT(SERVICE_LAUNCH_PROTECTED_WINDOWS_LIGHT);
  SETINT(SERVICE_LAUNCH_PROTECTED_ANTIMALWARE_LIGHT);
#endif

#if defined(_WINNT_VER) && _WINNT_VER > _WIN32_WINNT_WIN7
  SETINT(SERVICE_TRIGGER_ACTION_SERVICE_START);
  SETINT(SERVICE_TRIGGER_ACTION_SERVICE_STOP);
#endif

  SETINT(SC_ACTION_NONE);
  SETINT(SC_ACTION_RESTART);
  SETINT(SC_ACTION_REBOOT);
  SETINT(SC_ACTION_RUN_COMMAND);

  return 1;
}
