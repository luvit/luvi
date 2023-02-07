@echo off

set GENERATOR=Visual Studio 12
reg query HKEY_CLASSES_ROOT\VisualStudio.DTE.14.0 >nul 2>nul
IF %errorlevel%==0 set GENERATOR=Visual Studio 14
reg query HKEY_CLASSES_ROOT\VisualStudio.DTE.15.0 >nul 2>nul
IF %errorlevel%==0 set GENERATOR=Visual Studio 15
reg query HKEY_CLASSES_ROOT\VisualStudio.DTE.16.0 >nul 2>nul
IF %errorlevel%==0 set GENERATOR=Visual Studio 16
reg query HKEY_CLASSES_ROOT\VisualStudio.DTE.17.0 >nul 2>nul
IF %errorlevel%==0 set GENERATOR=Visual Studio 17

if "%ARCH%" == "i686" set PLATFORM=-G%GENERATOR% -AWin32
if "%ARCH%" == "x86_64" set PLATFORM=-G%GENERATOR% -Ax64

if "%PLATFORM%-%PROCESSOR_ARCHITECTURE%" == "-AMD64" set PLATFORM=-G%GENERATOR% -Ax64
if "%PLATFORM%-" == "-" set PLATFORM=-G%GENERATOR% -AWin32

IF NOT "x%1" == "x" GOTO :%1

GOTO :build

:regular
ECHO "Building regular"
cmake -DWithOpenSSL=ON -DWithPCRE=ON -DWithLPEG=ON -H. -Bbuild %PLATFORM% %EXTRA_OPTIONS%
GOTO :end

:tiny
ECHO "Building tiny"
cmake -H. -Bbuild %PLATFORM% %EXTRA_OPTIONS%
GOTO :end

:build
IF NOT EXIST build CALL Make.bat regular
cmake --build build --config Release -- /maxcpucount
COPY build\Release\luvi.exe .
GOTO :end

:test
IF NOT EXIST luvi.exe CALL Make.bat
luvi.exe samples\test.app -- 1 2 3 4
luvi.exe samples\test.app -o test.exe
test.exe 1 2 3 4
DEL /Q test.exe
GOTO :end

:clean
IF EXIST build RMDIR /S /Q build
IF EXIST luvi.exe DEL /F /Q luvi.exe
GOTO :end

:reset
git submodule update --init --recursive
git clean -f -d
git checkout .
GOTO :end

:end
