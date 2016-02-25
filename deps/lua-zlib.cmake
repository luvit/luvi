set(ZLIB_SHARED z)
set(ZLIB_STATIC zlibstatic)

set(LUA_ZLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-zlib)

if (WithSharedZLIB)
  set(LUA_ZLIB_LIB ${ZLIB_SHARED})
else ()
  set(LUA_ZLIB_LIB ${ZLIB_STATIC})
endif()

add_library(lua_zlib
  ${LUA_ZLIB_DIR}/lua_zlib.c
  ${LUA_ZLIB_DIR}/zlib.def
)

set_target_properties(lua_zlib PROPERTIES COMPILE_FLAGS -DLUA_LIB)

target_link_libraries(lua_zlib ${LUA_ZLIB_LIB})

set(EXTRA_LIBS ${EXTRA_LIBS} lua_zlib)

