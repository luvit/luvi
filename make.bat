@ECHO off

IF NOT "x%1" == "x" GOTO :%1

GOTO :tiny

:large
ECHO "Building large"
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
GOTO :build

:tiny
ECHO "Building tiny"
cmake -H. -Bbuild
GOTO :build

:build
cmake --build build --config Release -- /maxcpucount
COPY build\Release\luvi.exe .
GOTO :end

:test
SET LUVI_APP=samples\test.app
luvi.exe
SET LUVI_TARGET=test.exe
luvi.exe
SET "LUVI_APP="
SET "LUVI_TARGET="
test.exe
DEL /Q test.exe
GOTO :end

:clean
IF EXIST build RMDIR /S /Q build
IF EXIST luvi.exe DEL /F /Q luvi.exe
GOTO :end

:publish
ECHO "Building all versions"
git submodule update --init --recursive
CALL make.bat clean
CALL make.bat tiny
CALL make.bat test
COPY build\Release\luvi.exe luvi-binaries\Windows\luvi.exe
CALL make.bat clean
CALL make.bat large
CALL make.bat test
COPY build\Release\luvi.exe luvi-binaries\Windows\luvi-tiny.exe

:end
