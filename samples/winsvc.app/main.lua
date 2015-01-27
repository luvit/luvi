--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local table = require('table')
local winsvc = require('winsvc')
local winsvcaux = require('winsvcaux')
local uv = require('uv')

local svcname = 'Test Lua Service'
local gSvcStatus = {}
local gSvcStatusHandle
local gRunning = true

local function ReportSvcStatus(dwCurrentState, dwWin32ExitCode, dwWaitHint)
  local dwCheckPoint = 1

  -- Fill in the SERVICE_STATUS structure.

  gSvcStatus.dwCurrentState = dwCurrentState
  gSvcStatus.dwWin32ExitCode = dwWin32ExitCode
  gSvcStatus.dwWaitHint = dwWaitHint

  if dwCurrentState == winsvc.SERVICE_START_PENDING then
    gSvcStatus.dwControlsAccepted = 0
  else
    gSvcStatus.dwControlsAccepted = winsvc.SERVICE_ACCEPT_STOP
  end

  if dwCurrentState == winsvc.SERVICE_RUNNING or
    dwCurrentState == winsvc.SERVICE_STOPPED then
    gSvcStatus.dwCheckPoint = 0
  else
    dwCheckPoint = dwCheckPoint + 1
    gSvcStatus.dwCheckPoint = dwCheckPoint
  end

  -- Report the status of the service to the SCM.
  winsvc.SetServiceStatus(gSvcStatusHandle, gSvcStatus)
end


local function SvcHandler(dwControl, dwEventType, lpEventData, lpContext)
  -- Handle the requested control code. 

  if dwControl == winsvc.SERVICE_CONTROL_STOP then 
    ReportSvcStatus(winsvc.SERVICE_STOP_PENDING, winsvc.NO_ERROR, 0)

    -- Signal the service to stop.

    gRunning = false
    ReportSvcStatus(gSvcStatus.dwCurrentState, winsvc.NO_ERROR, 0)
         
    return winsvc.NO_ERROR
  elseif dwControl == winsvc.SERVICE_CONTROL_INTERROGATE then 
    return winsvc.NO_ERROR
  else
    return winsvc.ERROR_CALL_NOT_IMPLEMENTED
  end
end


local function SvcReportEvent(...)
  -- Log that somewhere
  local args = {...}
  local s
  if type(args) == 'string' then
    s = args
  else
    s = table.concat(args, ' ')
  end
  print(s)
  s = s .. '\n'
  -- synchronous file i/o for the logging so it can work even outside the event loop
  local fd, err = uv.fs_open('logfile.txt', 'a', tonumber('644', 8))
  if not err then
    uv.fs_write(fd, s, -1)
    uv.fs_close(fd)
  end
end


local function SvcInit(args, context)
  -- TO_DO: Declare and set any required variables.
  --   Be sure to periodically call ReportSvcStatus() with 
  --   SERVICE_START_PENDING. If initialization fails, call
  --   ReportSvcStatus with SERVICE_STOPPED.

  -- Create an event. The control handler function, SvcCtrlHandler,
  -- signals this event when it receives the stop control code.

  ReportSvcStatus(winsvc.SERVICE_RUNNING, winsvc.NO_ERROR, 0)

  -- TO_DO: Setup Serive Work To Be done
  
  local timer = uv.new_timer()
  uv.timer_start(timer, 0, 2000, function()
    if gRunning then
      SvcReportEvent('Just waiting...')
      uv.timer_again(timer)
    else
      uv.timer_stop(timer)
      uv.close(timer)
      ReportSvcStatus(winsvc.SERVICE_STOPPED, winsvc.NO_ERROR, 0);
      winsvc.EndService(context)
    end
  end)
end


local function SvcMain(args, context)
  gSvcStatusHandle = winsvc.GetStatusHandleFromContext(context)
  -- These SERVICE_STATUS members remain as set here

  gSvcStatus.dwServiceType = winsvc.SERVICE_WIN32_OWN_PROCESS
  gSvcStatus.dwServiceSpecificExitCode = 0

  -- Report initial status to the SCM

  ReportSvcStatus(winsvc.SERVICE_START_PENDING, winsvc.NO_ERROR, 3000)

  -- Perform service-specific initialization and work.

  SvcInit(args, context)
end


local function SvcInstall()
  local svcPath, err = winsvcaux.GetModuleFileName()
  if svcPath == nil then
    SvcReportEvent('Cannot install service, service path unobtainable', winsvcaux.GetErrorString(err))
    return
  end

  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    SvcReportEvent('OpenSCManager failed', winsvcaux.GetErrorString(err))
    return
  end

  -- Create the Service
  local schService, tagid, err = winsvc.CreateService(
    schSCManager,
    svcname,
    svcname,
    winsvc.SERVICE_ALL_ACCESS,
    winsvc.SERVICE_WIN32_OWN_PROCESS,
    winsvc.SERVICE_DEMAND_START,
    winsvc.SERVICE_ERROR_NORMAL,
    svcPath,
    nil,
    nil,
    nil,
    nil)

  if schService == nil then
    SvcReportEvent('CreateService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  -- Describe the service
  winsvc.ChangeServiceConfig2(schService, winsvc.SERVICE_CONFIG_DESCRIPTION, {lpDescription = "This is a test service written in Luvi/Lua"})
  -- Set the service to restart on failure in 15 seconds
  winsvc.ChangeServiceConfig2(schService, winsvc.SERVICE_CONFIG_FAILURE_ACTIONS,
    {dwResetPeriod = 0, lpsaActions = {
      {Delay = 15000, Type = winsvc.SC_ACTION_RESTART}
    }})

  SvcReportEvent('Service installed successfully')

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end


local function SvcDelete()
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    SvcReportEvent('OpenSCManager failed', winsvcaux.GetErrorString(err))
    return
  end

  -- Open the Service
  local schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.DELETE)

  if schService == nil then
    SvcReportEvent('OpenService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  local delsuccess, err = winsvc.DeleteService(schService)
  if not delsuccess then
    SvcReportEvent('DeleteService failed', winsvcaux.GetErrorString(err))
  else
    SvcReportEvent('DeleteService succeeded')
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end



local function SvcStart()
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    SvcReportEvent('OpenSCManager failed', winsvcaux.GetErrorString(err))
    return
  end

  -- Open the Service
  local schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.SERVICE_START)

  if schService == nil then
    SvcReportEvent('OpenService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  local startsuccess, err = winsvc.StartService(schService, nil)
  if not startsuccess then
    SvcReportEvent('StartService failed', winsvcaux.GetErrorString(err))
  else
    SvcReportEvent('StartService succeeded')
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end



local function SvcStop()
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    SvcReportEvent('OpenSCManager failed', winsvcaux.GetErrorString(err))
    return
  end

  -- Open the Service
  local schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.SERVICE_STOP)

  if schService == nil then
    SvcReportEvent('OpenService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  -- Stop the Service
  local success, status, err = winsvc.ControlService(schService, winsvc.SERVICE_CONTROL_STOP, nil)
  if not success then
    SvcReportEvent('ControlService stop failed', winsvcaux.GetErrorString(err))
  else
    local i, v, fstatus
    fstatus = {}
    for i, v in pairs(status) do
      table.insert(fstatus, i .. ': ' .. v)
    end
    SvcReportEvent('ControlService stop succeeded, status:', table.concat(fstatus, ', '))
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end



-- Main Code
if args[1] == 'install' then
  SvcInstall()
  return
elseif args[1] == 'delete' then
  SvcDelete()
  return
elseif args[1] == 'start' then
  SvcStart()
  return
elseif args[1] == 'stop' then
  SvcStop()
  return
end

local DispatchTable = {}
DispatchTable[svcname] = { SvcMain, SvcHandler };

local ret, err = winsvc.SpawnServiceCtrlDispatcher(DispatchTable, function(success, err)
  if success then
    SvcReportEvent('Service Control Dispatcher returned after threads exited ok')
  else
    SvcReportEvent('Service Control Dispatcher returned with err', winsvcaux.GetErrorString(err))
  end
end, function(err)
  SvcReportEvent('A Service function returned with err', err)
end)

if ret then
  SvcReportEvent('SpawnServiceCtrlDispatcher Succeeded')
else
  SvcReportEvent('SpawnServiceCtrlDispatcher Failed', winsvcaux.GetErrorString(err))
end

uv.run('default')
