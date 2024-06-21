set(LPEGLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/lpeg" CACHE PATH "Path to lpeg")

add_library(lpeglib STATIC
  ${LPEGLIB_DIR}/lpcap.c
  ${LPEGLIB_DIR}/lpcode.c
  ${LPEGLIB_DIR}/lpprint.c
  ${LPEGLIB_DIR}/lptree.c
  ${LPEGLIB_DIR}/lpvm.c
)

list(APPEND LUVI_LIBRARIES lpeglib)
list(APPEND LUVI_DEFINITIONS WITH_LPEG=1)
