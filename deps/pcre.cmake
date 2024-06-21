if (WithSharedPCRE)
  find_package(PCRE REQUIRED)

  message("Enabling Shared PCRE")
  message("PCRE_INCLUDE_DIR: ${PCRE_INCLUDE_DIR}")
  message("PCRE_LIBRARIES:   ${PCRE_LIBRARIES}")
else (WithSharedPCRE)
  message("Enabling Static PCRE")

  set(PCRE_MATCH_LIMIT "150000" CACHE STRING
      "Default limit on internal looping. See MATCH_LIMIT in config.h.in for details.")
  option(PCRE_BUILD_PCREGREP "Build pcregrep" OFF)
  option(PCRE_BUILD_TESTS    "Build the tests" OFF)
  option(PCRE_BUILD_PCRECPP "Build the PCRE C++ library (pcrecpp)." OFF)
  set(PCRE_SUPPORT_UTF ON CACHE BOOL
      "Enable support for Unicode Transformation Format (UTF-8/UTF-16/UTF-32) encoding.")

  set(BUILD_SHARED_LIBS OFF)
  add_compile_definitions(PCRE_STATIC)

  add_subdirectory(deps/pcre)

  set(PCRE_INCLUDE_DIR ${CMAKE_BINARY_DIR}/deps/pcre)
  set(PCRE_LIBRARIES pcre)
  
  message("PCRE_INCLUDE_DIR: ${PCRE_INCLUDE_DIR}")
  message("PCRE_LIBRARIES:   ${PCRE_LIBRARIES}")

  mark_as_advanced(PCRE_MATCH_LIMIT PCRE_BUILD_PCREGREP PCRE_BUILD_TESTS PCRE_BUILD_PCRECPP PCRE_SUPPORT_UTF)
endif (WithSharedPCRE)
