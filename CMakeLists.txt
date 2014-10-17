cmake_minimum_required(VERSION 2.8.9)

include(luv/luajit.cmake)
include(luv/uv.cmake)

luajit_add_executable(luvi
  src/main.c
  src/lua/init.lua
  src/lua/zipreader.lua
)

if(APPLE)
  set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  target_link_libraries(luvi uv lua51 rt)
else()
  target_link_libraries(luvi uv lua51)
endif()
