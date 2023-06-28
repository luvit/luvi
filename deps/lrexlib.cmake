set(LREXLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lrexlib)

include_directories(
  ${LREXLIB_DIR}/src
)

add_library(lrexlib
  ${LREXLIB_DIR}/src/common.c
  ${LREXLIB_DIR}/src/pcre2/lpcre2.c
  ${LREXLIB_DIR}/src/pcre2/lpcre2_f.c
)

set_target_properties(lrexlib PROPERTIES
    COMPILE_FLAGS "-DLUA_LIB -DLUA_COMPAT_APIINTCASTS -DVERSION=\\\"2.8.0\\\"")
target_link_libraries(lrexlib pcre2)

set(EXTRA_LIBS ${EXTRA_LIBS} lrexlib)
