#[=======================================================================[.rst:
FindLuv
--------

Find the native luv headers and libraries.

Result Variables
^^^^^^^^^^^^^^^^

This module defines the following variables:

``LUV_FOUND``
  "True" if ``luv`` found.

``LUV_INCLUDE_DIRS``
  where to find ``luv.h``, etc.

``LUV_LIBRARIES``
  List of libraries when using ``luv``.

#]=======================================================================]

include(FindPackageHandleStandardArgs)

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LUV QUIET libluv)
endif()

find_path(LUV_INCLUDE_DIR
  NAMES luv.h
  HINTS ${PC_LUV_INCLUDE_DIRS}
  PATH_SUFFIXES luv)
mark_as_advanced(LUV_INCLUDE_DIR)

find_library(LUV_LIBRARY
  NAMES luv
  HINTS ${PC_LUV_LIBRARY_DIRS})
mark_as_advanced(LUV_LIBRARY)

find_package_handle_standard_args(luv
  REQUIRED_VARS LUV_INCLUDE_DIR LUV_LIBRARY)

if (LUV_FOUND) # Set the output variables
  set(LUV_LIBRARIES ${LUV_LIBRARY})
  set(LUV_INCLUDE_DIRS ${LUV_INCLUDE_DIR})
endif ()
