local winsvc = require('winsvc')
local winsvcaux = require('winsvcaux')
local uv = require('uv')

local svcname = 'Test Lua Service'
local gSvcStatus = {}
local gServiceStatusHandle

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

  if dwControl == winsvc.SERVICE_CONTROL_USER_DISPATCHER_RUNNING then
    gServiceStatusHandle = winsvc.GetStatusHandleFrmContext(lpContext)
    ServiceMain(winsvc.GetArgsFromContext(lpContext), lpContext)
    return winsvc.NO_ERROR
  elseif dwControl == winsvc.SERVICE_CONTROL_STOP then 
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


local function SvcReportEvent(msg)
  -- Log that somewhere
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
  uv.timer_start(timer, 1000, 0, function()
    if gRunning then
      uv.time_set_repeat(timer, 1000)
    else
      uv.timer_stop(timer)
      ReportSvcStatus(winsvc.SERVICE_STOPPED, winsvc.NO_ERROR, 0);
      winsvc.EndService(context)
    end
  end)
end


local function SvcMain(args, context)
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
    print('Cannot install service, service path unobtainable', winsvcaux.GetErrorString(err))
    return
  end

  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    print('OpenSCManager failed', winsvcaux.GetErrorString(err))
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
    print('CreateService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  print('Service installed successfully')

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end


local function SvcDelete()
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    print('OpenSCManager failed', winsvcaux.GetErrorString(err))
    return
  end

  -- Open the Service
  local schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.DELETE)

  if schService == nil then
    print('OpenService failed', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  -- Delete the Service
  local schService = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.DELETE)

  local delsuccess, err = winsvc.DeleteService(schService)
  if not delsuccess then
    print('DeleteService failed', winsvcaux.GetErrorString(err))
  else
    print('DeleteService succeeded')
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
end

local DispatchTable = {}
DispatchTable[svcname] = SvcHandler;

-- Need to roll this into SpawnServiceCtrlDispatch to do it for each svcname
local svcpipe = uv.new_pipe(false)
svcpipe:bind(svcname)
local block

svcpipe:read_start(function(err, chunk)
  local success, dwControl, dwEventType, lpEventData, lpContext
  block, success, dwControl, dwEventType, lpEventData, lpContext = winsvc.FormatPipeReadChunk(block, chunk)
  if success then
    ret = SvcHandler(dwControl, dwEventType, lpEventData, lpContext)
    svcpipe:write(winsvc.FormatPipeReturn(ret))
  end
end)

if not winsvc.SpawnServiceCtrlDispatcher(DispatchTable) then
  SvcReportEvent('ServiceCtrlDispatcher Succeeded')
end

uv.run('default')
