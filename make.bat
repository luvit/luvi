@echo off

if "x%BUILD_TYPE%" == "x" (
  echo "Default Tiny Build"
  goto :tiny
) ELSE (
  echo "Building %BUILD_TYPE%"
  goto :%BUILD_TYPE%
) 

:large
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
goto build

:tiny
cmake -H. -Bbuild
goto build

:build
cmake --build build --config Release -- /maxcpucount
copy build\Release\luvi.exe .

:publish
rmdir /s /q build
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
cmake --build build --config Release
copy build\Release\luvi.exe luvi-binaries\Windows\luvi.exe
rmdir /s /q build
cmake -H. -Bbuild
cmake --build build --config Release
copy build\Release\luvi.exe luvi-binaries\Windows\luvi-tiny.exe
