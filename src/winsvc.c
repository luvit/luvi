#include "luvi.h"

#include <windows.h>
#include <winsvc.h>
#include <strsafe.h>

#define SERVICE_CONTROL_USER_REGISTER_HANDLER_FAIL		0x00000080
#define SERVICE_CONTROL_USER_DISPATCHER_RUNNING			0x00000081

struct svc_baton {
  const char* name;
  HANDLE end_event;
  SERVICE_STATUS_HANDLE status_handle;
  HANDLE* pipe;
  DWORD dwArgc;
  LPTSTR *lpszArgv;
};

struct svc_handler_block {
  DWORD dwControl;
  DWORD dwEventType;
  LPVOID lpEventData;
  LPVOID lpContext;
};

DWORD GetDWFromTable(lua_State *L, const char* name)
{
  DWORD result;
  lua_pushstring(L, name);
  lua_gettable(L, -2);  /* get table[key] */
  result = (int)lua_tonumber(L, -1);
  lua_pop(L, 1);  /* remove number */
  return result;
}

HANDLE* GetPipeHandle(const char* name)
{
  char pipename[MAX_PATH] = { '\0' };
  StringCchCat(pipename, MAX_PATH, TEXT("\\\\.\\pipe\\"));
  StringCchCat(pipename, MAX_PATH, name);
  HANDLE pipe = CreateFile(
    pipename,
    GENERIC_READ |  // read and write access 
    GENERIC_WRITE,
    0,              // no sharing 
    NULL,           // default security attributes
    OPEN_EXISTING,  // opens existing pipe 
    0,              // default attributes 
    NULL);          // no template file

  return pipe;
}

DWORD WINAPI HandlerEx(
  _In_  DWORD dwControl,
  _In_  DWORD dwEventType,
  _In_  LPVOID lpEventData,
  _In_  LPVOID lpContext)
{
  struct svc_baton *baton = lpContext;
  struct svc_handler_block block = { dwControl, dwEventType, lpEventData, lpContext };
  DWORD byteswritten, bytesread;
  DWORD returncode = ERROR;

  BOOL ret = WriteFile(baton->pipe, &block, sizeof(block), &byteswritten, NULL);
  if (ret) {
    BOOL ret = ReadFile(baton->pipe, &returncode, sizeof(returncode), &bytesread, NULL);
  }

  return returncode;
}

VOID WINAPI ServiceMain(_In_  DWORD dwArgc, _In_  LPTSTR *lpszArgv)
{
  struct svc_baton baton;
  baton.name = lpszArgv[0];
  baton.end_event = CreateEvent(NULL, FALSE, FALSE, baton.name);
  baton.pipe = GetPipeHandle(baton.name);
  baton.status_handle = RegisterServiceCtrlHandlerEx(baton.name, HandlerEx, &baton);
  baton.dwArgc = dwArgc;
  baton.lpszArgv = lpszArgv;

  if (baton.status_handle == 0)
  {
    HandlerEx(SERVICE_CONTROL_USER_REGISTER_HANDLER_FAIL, 0, 0, &baton);
  }
  else
  {
    HandlerEx(SERVICE_CONTROL_USER_DISPATCHER_RUNNING, 0, 0, &baton);
    WaitForSingleObject(baton.end_event, INFINITE);
  }
  CloseHandle(baton.pipe);
  CloseHandle(baton.end_event);
}

static int lua_GetStatusHandleFromContext(lua_State *L)
{
  struct svc_baton* baton = lua_touserdata(L, 1);
  lua_pushlightuserdata(L, baton->status_handle);
  return 1;
}

static int lua_EndService(lua_State *L)
{
  struct svc_baton* baton = lua_touserdata(L, 1);
  SetEvent(baton->end_event);
  return 0;
}

static int lua_FormatPipeReturn(lua_State *L)
{
  DWORD ret = luaL_checkint(L, 1);
  lua_pushlstring(L, (char*)&ret, sizeof(ret));
  return 1;
}

static int lua_FormatPipeReadChunk(lua_State *L)
{
  size_t chunklen, blocklen;
  const char* block = luaL_checklstring(L, 1, &blocklen);
  const char* chunk = luaL_checklstring(L, 2, &chunklen);
  size_t combinedlen = blocklen + chunklen;
  char* combined = (char*)malloc(combinedlen);

  memcpy(combined, block, blocklen);
  memcpy(combined + blocklen, chunk, chunklen);

  if (blocklen + chunklen >= sizeof(struct svc_handler_block))
  {
    struct svc_handler_block svcblock;
    char * blockreturned;
    size_t blockreturnedsz;

    memcpy(&svcblock, combined, sizeof(svcblock));
    blockreturned = combined + sizeof(svcblock);
    blockreturnedsz = combinedlen - sizeof(svcblock);

    // block, success, dwControl, dwEventType, lpEventData, lpContext
    lua_pushlstring(L, blockreturned, blockreturnedsz);
    lua_pushboolean(L, TRUE);
    lua_pushinteger(L, svcblock.dwControl);
    lua_pushinteger(L, svcblock.dwEventType);
    lua_pushlightuserdata(L, svcblock.lpEventData);
    lua_pushlightuserdata(L, svcblock.lpContext);
    free(combined);
    return 6;
  }
  else
  {
    lua_pushlstring(L, combined, combinedlen);
    lua_pushboolean(L, FALSE);
    free(combined);
    return 2;
  }
}

static int lua_GetServiceArgsFromContext(lua_State *L)
{
  struct svc_baton* baton = lua_touserdata(L, 1);
  lua_newtable(L);
  for (unsigned int i = 0; i <= baton->dwArgc; i++) {
    lua_pushnumber(L, i + 1);   /* Push the table index */
    lua_pushstring(L, baton->lpszArgv[i]); /* Push the cell value */
    lua_rawset(L, -3);      /* Stores the pair in the table */
  }
  return 1;
}

static int lua_SetServiceStatus(lua_State *L)
{
  SERVICE_STATUS status;
  SERVICE_STATUS_HANDLE SvcCtrlHandler = lua_touserdata(L, 1);
  if (!lua_istable(L, 2))
  {
    return luaL_error(L, "table expected");
  }

  status.dwCheckPoint = GetDWFromTable(L, "dwCheckPoint");
  status.dwControlsAccepted = GetDWFromTable(L, "dwControlsAccepted");
  status.dwCurrentState = GetDWFromTable(L, "dwCurrentState");
  status.dwServiceSpecificExitCode = GetDWFromTable(L, "dwServiceSpecificExitCode");
  status.dwServiceType = GetDWFromTable(L, "dwServiceType");
  status.dwWaitHint = GetDWFromTable(L, "dwWaitHint");
  status.dwWin32ExitCode = GetDWFromTable(L, "dwWin32ExitCode");

  BOOL ret = SetServiceStatus(SvcCtrlHandler, (LPSERVICE_STATUS)&status);
  if (ret)
  {
    lua_pushboolean(L, ret);
    lua_pushnil(L);
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

DWORD StartServiceCtrlDispatcherThread(LPVOID lpdwThreadParam)
{
  SERVICE_TABLE_ENTRY *svc_table = (SERVICE_TABLE_ENTRY*)lpdwThreadParam;
  return StartServiceCtrlDispatcher(svc_table);
}

static int lua_SpawnServiceCtrlDispatcher(lua_State *L)
{
  /* Get a table */
  BOOL ret = FALSE;
  if (!lua_istable(L, 1))
  {
    return luaL_error(L, "table expected");
  }

  size_t len = lua_objlen(L, 1);
  unsigned int i = 0;
  SERVICE_TABLE_ENTRY *svc_table = malloc(sizeof(SERVICE_TABLE_ENTRY) * (len + 1));
  /* Convert the table to a service table */
  lua_pushnil(L);  /* first key */
  while (lua_next(L, 1) != 0) {
    /* uses 'key' (at index -2) and 'value' (at index -1) */
    const char* name = luaL_checkstring(L, -2);
    int svchandler = luaL_ref(L, -1);

    svc_table[i].lpServiceName = (LPSTR)name;
    svc_table[i].lpServiceProc = ServiceMain;

    ++i;

    /* removes 'value'; keeps 'key' for next iteration */
    lua_pop(L, 1);
  }

  svc_table[i].lpServiceName = NULL;
  svc_table[i].lpServiceProc = NULL;


  /* Start */
  HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)&StartServiceCtrlDispatcherThread, svc_table, 0, NULL);
  ret = thread != NULL;

  lua_pushboolean(L, ret);
  if (ret)
  {
    lua_pushnil(L);
  }
  else
  {
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static int lua_OpenSCManager(lua_State *L)
{
  const char* machinename = lua_tostring(L, 1);
  const char* databasename = lua_tostring(L, 2);
  DWORD access = luaL_checkint(L, 3);
  SC_HANDLE h = OpenSCManager(machinename, databasename, access);
  if (h != NULL)
  {
    lua_pushlightuserdata(L, h);
    lua_pushnil(L);
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static int lua_OpenService(lua_State *L)
{
  SC_HANDLE hSCManager = lua_touserdata(L, 1);
  const char* servicename = luaL_checkstring(L, 2);
  DWORD access = luaL_checkint(L, 3);
  SC_HANDLE h = OpenService(hSCManager, servicename, access);
  if (h != NULL)
  {
    lua_pushlightuserdata(L, h);
    lua_pushnil(L);
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static int lua_CreateService(lua_State *L)
{
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
  if (h != NULL)
  {
    lua_pushlightuserdata(L, h);
    lua_pushinteger(L, tagid);
    lua_pushnil(L);
  }
  else
  {
    lua_pushnil(L);
    lua_pushnil(L);
    lua_pushinteger(L, GetLastError());
  }
  return 3;
}

static int lua_CloseServiceHandle(lua_State *L)
{
  SC_HANDLE h = lua_touserdata(L, 1);
  BOOL ret = CloseServiceHandle(h);
  lua_pushboolean(L, ret);
  if (ret)
  {
    lua_pushnil(L);
  }
  else
  {
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static int lua_DeleteService(lua_State *L)
{
  SC_HANDLE h = lua_touserdata(L, 1);
  BOOL ret = DeleteService(h);
  lua_pushboolean(L, ret);
  if (ret)
  {
    lua_pushnil(L);
  }
  else
  {
    lua_pushinteger(L, GetLastError());
  }
  return 2;
}

static const luaL_Reg winsvclib[] = {
    { "GetStatusHandleFromContext", lua_GetStatusHandleFromContext },
    { "GetServiceArgsFromContext", lua_GetServiceArgsFromContext },
    { "FormatPipeReadChunk", lua_FormatPipeReadChunk },
    { "FormatPipeReturn", lua_FormatPipeReturn },
    { "EndService", lua_EndService },
    { "SetServiceStatus", lua_SetServiceStatus },
    { "SpawnServiceCtrlDispatcher", lua_SpawnServiceCtrlDispatcher },
    { "OpenSCManager", lua_OpenSCManager },
    { "CloseServiceHandle", lua_CloseServiceHandle },
    { "CreateService", lua_CreateService },
    { "OpenService", lua_OpenService },
    { "DeleteService", lua_DeleteService },
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
  SETINT(SERVICE_CONTROL_PRESHUTDOWN);
  SETINT(SERVICE_CONTROL_TIMECHANGE);
  SETINT(SERVICE_CONTROL_TRIGGEREVENT);
  SETINT(SERVICE_CONTROL_USER_REGISTER_HANDLER_FAIL);

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
  SETINT(SERVICE_ACCEPT_PRESHUTDOWN);
  SETINT(SERVICE_ACCEPT_TIMECHANGE);
  SETINT(SERVICE_ACCEPT_TRIGGEREVENT);

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

  SETINT(SERVICE_CONTROL_STATUS_REASON_INFO);

  SETINT(SERVICE_SID_TYPE_NONE);
  SETINT(SERVICE_SID_TYPE_UNRESTRICTED);
  SETINT(SERVICE_SID_TYPE_RESTRICTED);

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

  SETINT(SERVICE_START_REASON_DEMAND);
  SETINT(SERVICE_START_REASON_AUTO);
  SETINT(SERVICE_START_REASON_TRIGGER);
  SETINT(SERVICE_START_REASON_RESTART_ON_FAILURE);
  SETINT(SERVICE_START_REASON_DELAYEDAUTO);

  SETINT(SERVICE_DYNAMIC_INFORMATION_LEVEL_START_REASON);

  SETINT(SERVICE_LAUNCH_PROTECTED_NONE);
  SETINT(SERVICE_LAUNCH_PROTECTED_WINDOWS);
  SETINT(SERVICE_LAUNCH_PROTECTED_WINDOWS_LIGHT);
  SETINT(SERVICE_LAUNCH_PROTECTED_ANTIMALWARE_LIGHT);

  return 1;
}
