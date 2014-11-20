@echo off

if "x%BUILD_TYPE%" == "x" (
  goto :tiny
) ELSE (
  goto :%BUILD_TYPE%
)

:large
echo "Building large"
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
goto build

:tiny
echo "Building tiny"
cmake -H. -Bbuild
goto build

:build
cmake --build build --config Release -- /maxcpucount
copy build\Release\luvi.exe .
goto end

:publish
echo "Building all versions"
rmdir /s /q build
cmake -DWithOpenSSL=ON -DWithSharedOpenSSL=OFF -H. -Bbuild
cmake --build build --config Release -- /maxcpucount
copy build\Release\luvi.exe luvi-binaries\Windows\luvi.exe
rmdir /s /q build
cmake -H. -Bbuild
cmake --build build --config Release -- /maxcpucount
copy build\Release\luvi.exe luvi-binaries\Windows\luvi-tiny.exe

:end
