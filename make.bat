@echo off

if NOT "x%1" == "x" goto :%1

if "x%BUILD_TYPE%" == "x" (
  goto :tiny
) ELSE (
  goto :%BUILD_TYPE%
)

:large
echo "Building large"
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
goto :build

:tiny
echo "Building tiny"
cmake -H. -Bbuild
goto :build

:build
cmake --build build --config Release -- /maxcpucount
copy build\Release\luvi.exe .
goto :end

:test
set LUVI_APP=samples\test.app
luvi.exe
set LUVI_TARGET=test.exe
luvi.exe
set "LUVI_APP="
set "LUVI_TARGET="
test.exe
del test.exe
goto :end

:publish
echo "Building all versions"
rmdir /s /q build
make.bat tiny
copy build\Release\luvi.exe luvi-binaries\Windows\luvi.exe
rmdir /s /q build
make.bat large
copy build\Release\luvi.exe luvi-binaries\Windows\luvi-tiny.exe

:end
