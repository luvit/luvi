set(SQLITE_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})

file(COPY
 ${SQLITE_ROOT_DIR}/sqlite3.h
 ${SQLITE_ROOT_DIR}/sqlite3ext.h
  DESTINATION ${CMAKE_BINARY_DIR}/sqlite/include/sqlite
)
include_directories(
  ${CMAKE_BINARY_DIR}/sqlite/include/sqlite
)
add_library(sqlite3 STATIC
  ${SQLITE_ROOT_DIR}/sqlite3.c
)
add_definitions(
  -DSQLITE_ENABLE_COLUMN_METADATA
)