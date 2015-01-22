if (WithSharedSqlite)
  find_package(Sqlite REQUIRED)

  message("Sqlite include dir: ${SQLITE3_INCLUDE_DIR}")
  message("Sqlite libraries: ${SQLITE3_LIBRARIES}")

  include_directories(${SQLITE3_INCLUDE_DIR})
  link_directories(${SQLITE3_ROOT_DIR}/lib)
  list(APPEND LIB_LIST ${SQLITE3_LIBRARIES})
else (WithSharedSqlite)
  message("Enabling Static Sqlite")
  include(deps/sqlite/sqlite.cmake)
  list(APPEND LIB_LIST sqlite3)
endif (WithSharedSqlite)

add_definitions(-DWITH_SQLITE)
include(deps/lua-sqlite.cmake)
