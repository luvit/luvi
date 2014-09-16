cmake_minimum_required(VERSION 3.0)

include(libuv.cmake)
include(luajit.cmake)

luajit_add_executable(luvi
  src/main.c
  src/lua/init.lua
  src/lua/zipreader.lua
)

target_link_libraries(luvi libuv libluajit)
