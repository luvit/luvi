cmake -H. -Bbuild
cmake --build build --config Release
copy build\Release\luvi.exe .
