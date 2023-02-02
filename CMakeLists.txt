cmake_minimum_required(VERSION 2.8.12)

if (WIN32)
  set(projects C ASM ASM_MASM)
else()
  set(projects C ASM)
endif()

project(luvi ${projects})

###############################################################################
## CMake Configuration
###############################################################################

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")

# use, i.e. don't skip the full RPATH for the build tree
set(CMAKE_SKIP_BUILD_RPATH FALSE CACHE INTERNAL "")
# when building, don't use the install RPATH already
# (but later on when installing)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE CACHE INTERNAL "")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib" CACHE INTERNAL "")
# add the automatically determined parts of the RPATH
# which point to directories outside the build tree to the install RPATH
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE CACHE INTERNAL "")
# the RPATH to be used when installing, but only if it's not a system directory
list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
if ("${isSystemDir}" STREQUAL "-1")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
endif("${isSystemDir}" STREQUAL "-1")

###############################################################################
## Luvi Configuration
###############################################################################

if (EXISTS "${CMAKE_SOURCE_DIR}/VERSION")
  file (STRINGS "${CMAKE_SOURCE_DIR}/VERSION" LUVI_VERSION)
else ()
  exec_program(
    "git" ${CMAKE_CURRENT_SOURCE_DIR}
    ARGS "describe" "--tags"
    OUTPUT_VARIABLE LUVI_VERSION
  )
endif()

message("-- Luvi Version: ${LUVI_VERSION}")

if (MSVC)
  # Statically build against C runtime (use the right version for Release/Debug)
  set(CompilerFlags
    CMAKE_CXX_FLAGS
    CMAKE_CXX_FLAGS_DEBUG
    CMAKE_CXX_FLAGS_RELEASE
    CMAKE_C_FLAGS
    CMAKE_C_FLAGS_DEBUG
    CMAKE_C_FLAGS_RELEASE
  )

  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
  endforeach()
endif()

option(WithSharedLibluv "Shared or Static libluv" OFF)
option(WithSharedLibuv "Shared or Static libuv" OFF)
option(WithSharedLua "Shared or Static Lua" OFF)
option(WithOpenSSL "Include OpenSSL" OFF)
option(WithOpenSSLASM "Enable Assembly Optimizations" OFF)
option(WithSharedOpenSSL "Shared or Static OpenSSL" OFF)
option(WithPCRE "Include PCRE" OFF)
option(WithSharedPCRE "Shared or Static PCRE" OFF)
option(WithLPEG "Include LPEG" OFF)
option(WithSharedLPEG "Shared or Static LPEG" OFF)
option(WithZLIB "Include ZLIB" OFF)
option(WithSharedZLIB "Shared or Static ZLIB" OFF)

if (CMAKE_COMPILER_IS_GNUCC)
  add_definitions( -Wno-unused-function )
endif()

if (UNIX)
  add_definitions( -Wall )
endif()

# Shared Libluv implies shared libuv
if (WithSharedLibluv OR WithSharedLibuv)
  find_package(Libuv)
  if (LIBUV_FOUND)
    include_directories( ${LIBUV_INCLUDE_DIR} )
  endif()

  message("LIBUV_INCLUDE_DIR: ${LIBUV_INCLUDE_DIR}")
  message("LIBUV_LIBRARIES: ${LIBUV_LIBRARIES}")

  set (LUVI_LIBRARIES ${LUVI_LIBRARIES} ${LIBUV_LIBRARIES})
endif()

# Shared Libluv implies shared lua
if (WithSharedLibluv OR WithSharedLua)
  if (WITH_LUA_ENGINE STREQUAL Lua)
    find_package(Lua)
    if (LUA_FOUND)
      include_directories( ${LUA_INCLUDE_DIR} )
    endif()

    message("LUA_INCLUDE_DIR: ${LUA_INCLUDE_DIR}")
    message("LUA_LIBRARIES: ${LUA_LIBRARIES}")

    set(LUVI_LIBRARIES ${LUVI_LIBRARIES} ${LUA_LIBRARIES})

    # For lua_add_executable, this still builds lua, can we avoid this?
    # We can effectively only link with a system version of whatever is provided in luv.
    include( deps/luv/deps/lua.cmake )
  else ()
    find_package(LuaJIT)
    if (LUAJIT_FOUND)
      include_directories( ${LUAJIT_INCLUDE_DIR} )
    endif()

    message("LUAJIT_INCLUDE_DIR: ${LUAJIT_INCLUDE_DIR}")
    message("LUAJIT_LIBRARIES: ${LUAJIT_LIBRARIES}")

    include(LuaJITAddExecutable)
    set(LUVI_LIBRARIES ${LUVI_LIBRARIES} ${LUAJIT_LIBRARIES})
  endif()
endif()

if (WithSharedLibluv)
  find_package(Libluv)
  if (LIBLUV_FOUND)
    include_directories( ${LIBLUV_INCLUDE_DIR} )
  endif()

  message("LIBLUV_INCLUDE_DIR: ${LIBLUV_INCLUDE_DIR}")
  message("LIBLUV_LIBRARIES: ${LIBLUV_LIBRARIES}")

  set(LUVI_LIBRARIES ${LUVI_LIBRARIES} ${LIBLUV_LIBRARIES})
else (WithSharedLibluv)
  set(BUILD_MODULE OFF CACHE BOOL "Turn off building luv as module")
  set(BUILD_STATIC_LIBS ON CACHE BOOL "Build luv as static lib")

  set(LUVI_LIBRARIES ${LUVI_LIBRARIES} libluv_a)
  
  if (WithSharedLibuv)
    set(WITH_SHARED_LIBUV ON CACHE BOOL "Link to shared libuv")
  else()
    set(LUVI_LIBRARIES ${LUVI_LIBRARIES} uv_a) # uv_a is provided by luv
  endif()

  if (WithSharedLua)
    set(LUA_BUILD_TYPE "System" CACHE STRING "Use the system Lua")
  else()
    if (WITH_LUA_ENGINE STREQUAL Lua)
      include_directories( deps/luv/deps/lua )
      set(LUVI_LIBRARIES ${LUVI_LIBRARIES} lualib)
    else()
      include_directories( deps/luv/deps/luajit/src )
      set(LUVI_LIBRARIES ${LUVI_LIBRARIES} luajit-5.1)
    endif()
  endif()

  include_directories( deps/luv/src )
  include_directories( deps/luv/deps/libuv/include )

  add_subdirectory(deps/luv)
endif(WithSharedLibluv)

set(LUA_COMPAT53_DIR deps/luv/deps/lua-compat-5.3)
if (DEFINED ENV{LUA_COMPAT53_DIR})
  set(LUA_COMPAT53_DIR $ENV{LUA_COMPAT53_DIR})
endif()
include_directories( ${LUA_COMPAT53_DIR} )
include_directories( ${LUA_COMPAT53_DIR}/c-api )

if (WithOpenSSL)
  include(deps/openssl.cmake)
endif(WithOpenSSL)

if (WithPCRE)
  include (deps/pcre.cmake)
endif(WithPCRE)

if (WithLPEG)
  include (deps/lpeg.cmake)
endif(WithLPEG)

if (WithZLIB)
  include(deps/zlib.cmake)
endif(WithZLIB)

add_definitions( -DLUVI_VERSION="${LUVI_VERSION}" )

if (WIN32)
  set(winsvc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/winsvc.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/winsvcaux.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/winsvc.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/winsvcaux.c
  )
  if (WithSharedLibluv)
    add_definitions( -DLUA_BUILD_AS_DLL -DBUILDING_UV_SHARED )
  endif()
  add_definitions( -DWITH_WINSVC )
  add_definitions( -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS )

  add_library (luvi_renamed src/luvi_renamed.c)
endif()

if (WITH_LUA_ENGINE STREQUAL Lua)
  add_definitions( -DWITH_PLAIN_LUA )
endif()

if (LPEGLIB_DIR)
  set(lpeg_re_lua ${LPEGLIB_DIR}/re.lua)
endif()

lua_add_executable(luvi
  ${winsvc}
  ${CMAKE_CURRENT_SOURCE_DIR}/src/main.c
  ${CMAKE_CURRENT_SOURCE_DIR}/src/luvi_compat.c
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lua/init.lua
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lua/luvipath.lua
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lua/luvibundle.lua
  ${lpeg_re_lua}
)

if (${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
  set(CMAKE_EXE_LINKER_FLAGS "-Wl,-E")
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  set(EXTRA_LIBS ${EXTRA_LIBS} rt)
endif()

find_package(Threads)

target_link_libraries(luvi ${LUVI_LIBRARIES} ${EXTRA_LIBS} ${CMAKE_THREAD_LIBS_INIT})
set_target_properties(luvi PROPERTIES ENABLE_EXPORTS ON)

###############################################################################
## Installation Targets
###############################################################################

install(TARGETS luvi DESTINATION bin)
