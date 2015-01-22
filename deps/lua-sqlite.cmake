set(LUA_SQLITE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-sqlite)

include_directories(
  ${LUA_SQLITE_DIR}
)

add_library(lua_sqlite
  ${LUA_SQLITE_DIR}/lsqlite.c
)

target_link_libraries(lua_sqlite sqlite3)

set(EXTRA_LIBS ${EXTRA_LIBS} lua_sqlite)
