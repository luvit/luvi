#[=======================================================================[.rst:
FindLibuv
--------

Find the native libuv headers and libraries.

Result Variables
^^^^^^^^^^^^^^^^

This module defines the following variables:

``LIBUV_FOUND``
  "True" if ``libuv`` found.

``LIBUV_INCLUDE_DIRS``
  where to find ``uv.h``, etc.

``LIBUV_LIBRARIES``
  List of libraries when using ``uv``.

#]=======================================================================]

include(FindPackageHandleStandardArgs)

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(PC_UV QUIET libuv)
endif()

find_path(UV_INCLUDE_DIR
  NAMES uv.h
  HINTS ${PC_UV_INCLUDE_DIRS})
mark_as_advanced(UV_INCLUDE_DIR)

find_library(UV_LIBRARY
  NAMES uv
  HINTS ${PC_UV_LIBRARY_DIRS})
mark_as_advanced(UV_LIBRARY)

find_package_handle_standard_args(Libuv
  REQUIRED_VARS UV_INCLUDE_DIR UV_LIBRARY)

if (LIBUV_FOUND) # Set the output variables
  set(LIBUV_LIBRARIES ${UV_LIBRARY})
  set(LIBUV_INCLUDE_DIRS ${UV_INCLUDE_DIR})
endif ()
