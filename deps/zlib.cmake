if (WithSharedZLIB)
  find_package(ZLIB REQUIRED)

  message("Enabling Shared ZLIB")
  message("ZLIB_INCLUDE_DIR: ${ZLIB_INCLUDE_DIR}")
  message("ZLIB_LIBRARIES:   ${ZLIB_LIBRARIES}")
else (WithSharedZLIB)
  message("Enabling Static ZLIB")
  add_subdirectory(deps/zlib)

  set(ZLIB_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/zlib ${CMAKE_BINARY_DIR}/deps/zlib)
  set(ZLIB_LIBRARIES zlibstatic)

  message("ZLIB_INCLUDE_DIR: ${ZLIB_INCLUDE_DIR}")
  message("ZLIB_LIBRARIES:   ${ZLIB_LIBRARIES}")
endif (WithSharedZLIB)
