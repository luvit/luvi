# Locate LuaJIT library
# This module defines
#  LUAJIT_FOUND, if false, do not try to link to Lua JIT
#  LUAJIT_LIBRARIES
#  LUAJIT_INCLUDE_DIR, where to find lua.h

FIND_PATH(LUAJIT_INCLUDE_DIR NAMES lua.h lauxlib.h PATH_SUFFIXES luajit-2.0 luajit-2.1)
FIND_LIBRARY(LUAJIT_LIBRARIES NAMES luajit-5.1 PATH_SUFFIXES luajit-2.0 luajit-2.1)

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(LuaJIT DEFAULT_MSG LUAJIT_LIBRARIES LUAJIT_INCLUDE_DIR)
