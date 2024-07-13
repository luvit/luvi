#[=======================================================================[.rst:
FindPCRE2
--------

Find the native pcre2 (specifically the 8-bit version) headers and libraries.

Result Variables
^^^^^^^^^^^^^^^^

This module defines the following variables:

``PCRE2_FOUND``
  "True" if ``pcre2-8`` found.

``PCRE2_INCLUDE_DIRS``
  where to find ``pcre2.h``, etc.

``PCRE2_LIBRARIES``
  List of libraries when using ``pcre2-8``.

#]=======================================================================]

include(FindPackageHandleStandardArgs)

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(PC_PCRE2 QUIET libpcre2-8)
endif()

find_path(PCRE2_INCLUDE_DIR
  NAMES pcre2.h
  HINTS ${PC_PCRE2_INCLUDE_DIRS})
mark_as_advanced(PCRE2_INCLUDE_DIR)

find_library(PCRE2_LIBRARY
  NAMES pcre2-8
  HINTS ${PC_PCRE2_LIBRARY_DIRS})
mark_as_advanced(PCRE2_LIBRARY)

find_package_handle_standard_args(PCRE2
  REQUIRED_VARS PCRE2_INCLUDE_DIR PCRE2_LIBRARY)

if (PCRE2_FOUND) # Set the output variables
  set(PCRE2_LIBRARIES ${PCRE2_LIBRARY})
  set(PCRE2_INCLUDE_DIRS ${PCRE2_INCLUDE_DIR})
endif ()
