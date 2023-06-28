
if (WithSharedPCRE2)
  find_package(PCRE2 REQUIRED)
  message("PCRE2 include dir: ${PCRE2_INCLUDE_DIR}")
  message("PCRE2 libraries: ${PCRE2_LIBRARIES}")
  include_directories(${PCRE2_INCLUDE_DIR})
  link_directories(${PCRE2_ROOT_DIR}/lib)
  list(APPEND LIB_LIST ${PCRE2_LIBRARIES})
else (WithSharedPCRE2)
  SET(PCRE2_MATCH_LIMIT "150000" CACHE STRING
      "Default limit on internal looping. See MATCH_LIMIT in config.h.in for details.")
  OPTION(PCRE2_BUILD_PCREGREP "Build pcregrep" OFF)
  OPTION(PCRE2_BUILD_TESTS    "Build the tests" OFF)
  OPTION(PCRE2_BUILD_PCRECPP "Build the PCRE C++ library (pcrecpp)." OFF)
  SET(PCRE2_SUPPORT_UTF ON CACHE BOOL
      "Enable support for Unicode Transformation Format (UTF-8/UTF-16/UTF-32) encoding.")

  include_directories(${CMAKE_BINARY_DIR}/deps/pcre2)
  add_subdirectory(deps/pcre2)
  message("Enabling Static PCRE2")
  list(APPEND EXTRA_LIBS pcre2)
  add_definitions(-DPCRE_STATIC)
endif (WithSharedPCRE2)

add_definitions(-DWITH_PCRE2)
include(deps/lrexlib.cmake)
