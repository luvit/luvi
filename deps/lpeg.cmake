include_directories(
  ${LPEGLIB_DIR}
)

add_library(LPEGLIB
  ${LPEGLIB_DIR}/lpcap.c
  ${LPEGLIB_DIR}/lpcode.c
  ${LPEGLIB_DIR}/lpprint.c
  ${LPEGLIB_DIR}/lptree.c
  ${LPEGLIB_DIR}/lpvm.c
)

set(EXTRA_LIBS ${EXTRA_LIBS} LPEGLIB)

add_definitions(-DLUA_LIB -DWITH_LPEG)
remove_definitions(-DNDEBUG)
remove_definitions(-DVERSION)
