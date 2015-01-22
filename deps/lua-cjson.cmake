set(LUA_CJSON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-cjson)

include_directories(
  ${LUA_CJSON_DIR}
)

add_library(lua_cjson
  ${LUA_CJSON_DIR}/lua_cjson.c
  ${LUA_CJSON_DIR}/strbuf.c
  ${LUA_CJSON_DIR}/fpconv.c
)

set(EXTRA_LIBS ${EXTRA_LIBS} lua_cjson)

add_definitions(-DWITH_CJSON)
