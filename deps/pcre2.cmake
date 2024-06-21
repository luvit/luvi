if (WithSharedPCRE2)
  find_package(PCRE2 REQUIRED)

  message("Enabling Shared PCRE2")
  message("PCRE2_INCLUDE_DIR: ${PCRE2_INCLUDE_DIR}")
  message("PCRE2_LIBRARIES:   ${PCRE2_LIBRARIES}")
else (WithSharedPCRE2)
  message("Enabling Static PCRE2")

  set(PCRE2_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/pcre2" CACHE STRING "Path to pcre2")

  set(PCRE2_BUILD_PCRE2GREP OFF CACHE BOOL "Build pcre2grep")
  set(PCRE2_BUILD_TESTS OFF CACHE BOOL "Build tests")
  set(PCRE2_STATIC_RUNTIME ON CACHE BOOL "Use static runtime")
  set(PCRE2_SUPPORT_LIBBZ2 OFF CACHE BOOL "Support libbz2")
  set(PCRE2_SUPPORT_LIBZ OFF CACHE BOOL "Support libz")
  set(PCRE2_SUPPORT_LIBEDIT OFF CACHE BOOL "Support libedit")
  set(PCRE2_SUPPORT_LIBREADLINE OFF CACHE BOOL "Support libreadline")

  add_compile_definitions(PCRE2_CODE_UNIT_WIDTH=8)
  add_compile_definitions(PCRE2_STATIC)

  add_subdirectory(deps/pcre2)

  set(PCRE2_INCLUDE_DIR ${PCRE2_HEADERS})
  set(PCRE2_LIBRARIES pcre2-8-static)
  
  message("PCRE2_INCLUDE_DIR: ${PCRE2_INCLUDE_DIR}")
  message("PCRE2_LIBRARIES:   ${PCRE2_LIBRARIES}")
endif (WithSharedPCRE2)
