set(LREXLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lrexlib)

include_directories(
  ${LREXLIB_DIR}/src
)

add_library(lrexlib
  ${LREXLIB_DIR}/src/common.c
  ${LREXLIB_DIR}/src/pcre/lpcre.c
  ${LREXLIB_DIR}/src/pcre/lpcre_f.c
)

set_target_properties(lrexlib PROPERTIES
    COMPILE_FLAGS "-DLUA_LIB -DLUA_COMPAT_APIINTCASTS -DVERSION=\\\"2.8.0\\\"")
target_link_libraries(lrexlib pcre)

set(EXTRA_LIBS ${EXTRA_LIBS} lrexlib)
