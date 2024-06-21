include(deps/zlib.cmake)

set(LUA_ZLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-zlib" CACHE STRING "Path to lua-zlib")

add_library(lua_zlib STATIC
  ${LUA_ZLIB_DIR}/lua_zlib.c
  ${LUA_ZLIB_DIR}/zlib.def
)

target_include_directories(lua_zlib PUBLIC ${ZLIB_INCLUDE_DIR})
target_link_libraries(lua_zlib ${ZLIB_LIBRARIES})

list(APPEND LUVI_LIBRARIES lua_zlib ${ZLIB_LIBRARIES})
list(APPEND LUVI_DEFINITIONS WITH_ZLIB=1)
