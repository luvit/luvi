set(LUA_LBUFFER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lbuffer)

add_library(lua_lbuffer
  ${LUA_LBUFFER_DIR}/lbuffer.c
  ${LUA_LBUFFER_DIR}/lbufflib.c
)

add_definitions(-DluaI_openlib=luaL_openlib)
include_directories(${LUA_LBUFFER_DIR})

set(EXTRA_LIBS ${EXTRA_LIBS} lua_lbuffer)

