include(deps/pcre2.cmake)

set(LREXLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/lrexlib" CACHE PATH "Path to lrexlib")

add_library(lrexlib STATIC
  ${LREXLIB_DIR}/src/common.c
  ${LREXLIB_DIR}/src/pcre2/lpcre2.c
  ${LREXLIB_DIR}/src/pcre2/lpcre2_f.c
)

target_include_directories(lrexlib PUBLIC ${PCRE2_INCLUDE_DIR})
target_link_libraries(lrexlib ${PCRE2_LIBRARIES})
target_compile_definitions(lrexlib PRIVATE
  LUA_COMPAT_APIINTCASTS
  VERSION="2.8.0")

list(APPEND LUVI_LIBRARIES lrexlib ${PCRE2_LIBRARIES})
list(APPEND LUVI_DEFINITIONS WITH_PCRE2=1)
