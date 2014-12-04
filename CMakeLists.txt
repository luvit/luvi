cmake_minimum_required(VERSION 2.8.9)

project(luvi C)

exec_program(
    "git"
    ${CMAKE_CURRENT_SOURCE_DIR}
    ARGS "describe" "--tags"
    OUTPUT_VARIABLE LUVI_VERSION)

option(WithOpenSSL "Include OpenSSL" OFF)
option(WithSharedOpenSSL "Shared or Static OpenSSL" ON)
option(WithZLIB "Include ZLIB" OFF)
option(WithSharedZLIB "Shared or Static ZLIB" ON)

include(deps/luv/luajit.cmake)
include(deps/luv/uv.cmake)

if (WithOpenSSL)
  include(deps/openssl.cmake)
endif (WithOpenSSL)

if (WithZLIB)
  include(deps/zlib.cmake)
endif (WithZLIB)

add_definitions( -DLUVI_VERSION="${LUVI_VERSION}" )

luajit_add_executable(luvi
  src/main.c
  src/lua/init.lua
)

if(APPLE)
  set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  target_link_libraries(luvi uv lua51 rt ${EXTRA_LIBS})
else()
  target_link_libraries(luvi uv lua51 ${EXTRA_LIBS})
endif()



