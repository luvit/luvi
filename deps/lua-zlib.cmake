set(LUA_ZLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-zlib)

add_library(lua_zlib
  ${LUA_ZLIB_DIR}/lua_zlib.c
  ${LUA_ZLIB_DIR}/zlib.def
)

target_link_libraries(lua_zlib zlib)

set(EXTRA_LIBS ${EXTRA_LIBS} lua_zlib)

