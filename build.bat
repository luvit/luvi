
@ECHO
@ECHO "Building luajit"
@ECHO
cd luajit-2.0\src
CALL msvcbuild.bat static

@ECHO
@ECHO "Compiling luvi lua modules to C"
@ECHO
luajit.exe -bg ..\..\src\lua\init.lua ..\..\init.lua.c
luajit.exe -bg ..\..\src\lua\zipreader.lua ..\..\zipreader.lua.c
cd ..\..

@ECHO
@ECHO "Building libuv"
@ECHO
cd luv\libuv
call ..\..\tools\gyp\gyp.bat --depth=. -D target_arch=ia32 -f msvs -G msvs_version=auto -G output_dir-out --generator-output out -I common.gypi -D library=static_library
cd out
msbuild libuv.vcxproj /p:Configuration=Release
cd ..\..\..

@ECHO
@ECHO "Building luvi"
@ECHO
cl /nologo /I luajit-2.0\src /I luv\libuv\include src\main.c luajit-2.0\src\lua51.lib luv\libuv\out\Release\lib\libuv.lib ws2_32.lib psapi.lib iphlpapi.lib advapi32.lib /link /LTCG /OUT:luvi.exe
