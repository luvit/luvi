# Locate libluv library
# This module defines
#  LIBLUV_FOUND, if false, do not try to link to libluv
#  LIBLUV_LIBRARIES
#  LIBLUV_INCLUDE_DIR, where to find uv.h

FIND_PATH(LIBLUV_INCLUDE_DIR luv.h PATH_SUFFIXES luv)
FIND_LIBRARY(LIBLUV_LIBRARIES luv)

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(Libluv DEFAULT_MSG LIBLUV_LIBRARIES LIBLUV_INCLUDE_DIR)
