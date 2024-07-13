#[=======================================================================[.rst:
FindLuajit
--------

Find the native luajit headers and libraries.

Result Variables
^^^^^^^^^^^^^^^^

This module defines the following variables:

``LUAJIT_FOUND``
  "True" if ``luajit`` found.

``LUAJIT_INCLUDE_DIRS``
  where to find ``lua.h``, etc.

``LUAJIT_LIBRARIES``
  List of libraries when using ``luajit``.

#]=======================================================================]

include(FindPackageHandleStandardArgs)

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LUAJIT QUIET luajit)
endif()

find_path(LUAJIT_INCLUDE_DIR
  NAMES lua.h
  HINTS ${PC_LUAJIT_INCLUDE_DIRS}
  PATH_SUFFIXES luajit-2.0)
mark_as_advanced(LUAJIT_INCLUDE_DIR)

find_library(LUAJIT_LIBRARY
  NAMES luajit-5.1
  HINTS ${PC_LUAJIT_LIBRARY_DIRS}
  PATH_SUFFIXES luajit-2.0)
mark_as_advanced(LUAJIT_LIBRARY)

find_package_handle_standard_args(LuaJIT
  REQUIRED_VARS LUAJIT_INCLUDE_DIR LUAJIT_LIBRARY)

if (LUAJIT_FOUND) # Set the output variables
  set(LUAJIT_LIBRARIES ${LUAJIT_LIBRARY})
  set(LUAJIT_INCLUDE_DIRS ${LUAJIT_INCLUDE_DIR})
endif ()
