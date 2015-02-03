if (WithSharedZLIB)
  find_package(ZLIB REQUIRED)

  message("ZLIB include dir: ${ZLIB_INCLUDE_DIR}")
  message("ZLIB libraries: ${ZLIB_LIBRARIES}")

  include_directories(${ZLIB_INCLUDE_DIR})
  link_directories(${ZLIB_ROOT_DIR}/lib)
else (WithSharedZLIB)
  message("Enabling Static ZLIB")
  add_subdirectory(deps/zlib)
  include_directories(deps/zlib)
  include_directories(build/deps/zlib)
endif (WithSharedZLIB)

add_definitions(-DWITH_ZLIB)
include(deps/lua-zlib.cmake)
