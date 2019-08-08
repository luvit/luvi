#include "windows.h"
#include "delayimp.h"
FARPROC WINAPI LoadFailureHook(unsigned dliNotify, PDelayLoadInfo pdli);
#if _MSC_FULL_VER >= 190024210 // MSVC 2015 Update 3
#ifndef DELAYIMP_INSECURE_WRITABLE_HOOKS
const
#endif
#endif
PfnDliHook __pfnDliFailureHook2 = LoadFailureHook;


FARPROC WINAPI LoadFailureHook(unsigned dliNotify, PDelayLoadInfo pdli)
{
    if (dliNotify == dliFailLoadLib) {
        if (_stricmp("luvi.exe", pdli->szDll) == 0) {
            TCHAR name[MAX_PATH + 1];
            DWORD ret = GetModuleFileName(NULL, name, MAX_PATH + 1);
            if (ret > 0) {
                HMODULE module = LoadLibrary(name);
                if (module) {
                    return (FARPROC)module;
                }
            }
        }
    }
    return 0;
}

