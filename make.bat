@ECHO off

for /f %%i in ('git describe') do set LUVI_TAG=%%i
IF NOT "x%1" == "x" GOTO :%1

GOTO :build

:regular
ECHO "Building regular64"
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild  -G"Visual Studio 12 Win64"
GOTO :end

:regular-asm
ECHO "Building regular64 asm"
cmake -DWithOpenSSLASM=ON -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild  -G"Visual Studio 12 Win64"
GOTO :end

:regular32
ECHO "Building regular32"
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild  -G"Visual Studio 12"
GOTO :end

:regular32-asm
ECHO "Building regular32 asm"
cmake -DWithOpenSSLASM=ON -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild  -G"Visual Studio 12"
GOTO :end

:tiny
ECHO "Building tiny64"
cmake -H. -Bbuild -G"Visual Studio 12 Win64"
GOTO :end

:tiny32
ECHO "Building tiny32"
cmake -H. -Bbuild -G"Visual Studio 12"
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

:winsvc
IF NOT EXIST luvi.exe CALL Make.bat
DEL /Q winsvc.exe
luvi.exe samples\winsvc.app -o winsvc.exe
GOTO :end

:repl
IF NOT EXIST luvi.exe CALL Make.bat
DEL /Q repl.exe
luvi.exe samples/repl.app -o repl.exe
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

:publish-tiny
CALL make.bat reset
CALL make.bat tiny
CALL make.bat test
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file luvi.exe --name luvi-tiny-Windows-amd64.exe
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi.lib --name luvi-tiny-Windows-amd64.lib
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi_renamed.lib --name luvi_renamed-tiny-Windows-amd64.lib
GOTO :end

:publish-tiny32
CALL make.bat reset
CALL make.bat tiny32
CALL make.bat test
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file luvi.exe --name luvi-tiny-Windows-ia32.exe
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi.lib --name luvi-tiny-Windows-ia32.lib
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi_renamed.lib --name luvi_renamed-tiny-Windows-ia32.lib
GOTO :end

:publish-regular
CALL make.bat reset
CALL make.bat regular
CALL make.bat test
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file luvi.exe --name luvi-regular-Windows-amd64.exe
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi.lib --name luvi-regular-Windows-amd64.lib
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi_renamed.lib --name luvi_renamed-regular-Windows-amd64.lib
GOTO :end

:publish-regular32
CALL make.bat reset
CALL make.bat regular32
CALL make.bat test
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file luvi.exe --name luvi-regular-Windows-ia32.exe
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi.lib --name luvi-regular-Windows-ia32.lib
github-release upload --user luvit --repo luvi --tag %LUVI_TAG% --file build\Release\luvi_renamed.lib --name luvi_renamed-regular-Windows-ia32.lib
GOTO :end

:publish
CALL make.bat clean
CALL make.bat publish-tiny
CALL make.bat clean
CALL make.bat publish-tiny32
CALL make.bat clean
CALL make.bat publish-regular
CALL make.bat clean
CALL make.bat publish-regular32

:end
