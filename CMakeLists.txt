cmake_minimum_required(VERSION 2.8.9)

if(WIN32)
  set(projects C ASM ASM_MASM)
else()
  set(projects C ASM)
endif()

project(luvi ${projects})

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")

# use, i.e. don't skip the full RPATH for the build tree
SET(CMAKE_SKIP_BUILD_RPATH FALSE CACHE INTERNAL "")
# when building, don't use the install RPATH already
# (but later on when installing)
SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE CACHE INTERNAL "")
SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib" CACHE INTERNAL "")
# add the automatically determined parts of the RPATH
# which point to directories outside the build tree to the install RPATH
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE CACHE INTERNAL "")
# the RPATH to be used when installing, but only if it's not a system directory
LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
IF("${isSystemDir}" STREQUAL "-1")
   SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
ENDIF("${isSystemDir}" STREQUAL "-1")

if(MSVC)
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

if(CMAKE_COMPILER_IS_GNUCC)
  add_definitions( -Wno-unused-function)
endif()

if (EXISTS "${CMAKE_SOURCE_DIR}/VERSION")
  file (STRINGS "${CMAKE_SOURCE_DIR}/VERSION" LUVI_VERSION)
  message("-- Found luvi version: ${LUVI_VERSION}")
else()
  exec_program(
      "git"
      ${CMAKE_CURRENT_SOURCE_DIR}
      ARGS "describe" "--tags"
      OUTPUT_VARIABLE LUVI_VERSION)
  message("-- Found luvi git version: ${LUVI_VERSION}")
endif()

option(WithSharedLibluv "Shared or Static libluv" OFF)
option(WithOpenSSL "Include OpenSSL" OFF)
option(WithOpenSSLASM "Enable Assembly Optimizations" OFF)
option(WithSharedOpenSSL "Shared or Static OpenSSL" ON)
option(WithPCRE "Include " OFF)
option(WithSharedPCRE "Shared or Static " OFF)
option(WithLPEG "Include " OFF)
option(WithSharedLPEG "Shared or Static " OFF)
option(WithZLIB "Include ZLIB" OFF)
option(WithSharedZLIB "Shared or Static ZLIB" ON)
option(WithPackageSH "Build shell-installable package." OFF)
option(WithPackageTGZ "Build gziped tarball package." OFF)
option(WithPackageTBZ2 "Build bzip2'd tarball package." OFF)
option(WithPackageDEB "Build DEB package." OFF)
option(WithPackageRPM "Build RPM package." OFF)
option(WithPackageNSIS "Build NSIS package." OFF)
option(WithPackageBUNDLE "Build OSX bundle." OFF)

find_package(Threads)

if (WithSharedLibluv)
  # Building against a shared libluv provides that libluajit and libuv exists
  find_package(Libluv)
  find_package(LuaJIT)
  find_package(Libuv)
  if (LIBLUV_FOUND)
    include_directories(${LIBLUV_INCLUDE_DIR})
  endif (LIBLUV_FOUND)
  if (LUAJIT_FOUND)
    include_directories(${LUAJIT_INCLUDE_DIR})
  endif (LUAJIT_FOUND)
  if (LIBUV_FOUND)
    include_directories(${LIBUV_INCLUDE_DIR})
  endif (LIBUV_FOUND)
  include(LuaJITAddExecutable)
  set(LUVI_LIBRARIES ${LIBLUV_LIBRARIES} ${LUAJIT_LIBRARIES} ${LIBUV_LIBRARIES})
else (WithSharedLibluv)
  # Build luv as static library instead of as module
  set(BUILD_MODULE OFF CACHE BOOL "Turn off building luv as module")
  set(BUILD_STATIC_LIBS ON CACHE BOOL "Build luv as static lib")
  include_directories(deps/luv/src)
  include_directories(deps/luv/deps/libuv/include)
  if (WITH_LUA_ENGINE STREQUAL Lua)
    include_directories(deps/luv/deps/lua/src)
    set(LUVI_LIBRARIES libluv_a lualib uv_a)
  else()
    include_directories(deps/luv/deps/luajit/src)
    set(LUVI_LIBRARIES libluv_a luajit-5.1 uv_a)
  endif()
  add_subdirectory(deps/luv)
endif (WithSharedLibluv)

set(LUA_COMPAT53_DIR deps/luv/deps/lua-compat-5.3)
if(DEFINED ENV{LUA_COMPAT53_DIR})
  set(LUA_COMPAT53_DIR $ENV{LUA_COMPAT53_DIR})
endif()
include_directories(${LUA_COMPAT53_DIR})
include_directories(${LUA_COMPAT53_DIR}/c-api)

if (WithOpenSSL)
  include(deps/openssl.cmake)
endif (WithOpenSSL)

if (WithPCRE)
  include (deps/pcre.cmake)
endif (WithPCRE)

if (WithLPEG)
  set(LPEGLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lpeg)
  if(DEFINED ENV{LPEGLIB_DIR})
    set(LPEGLIB_DIR $ENV{LPEGLIB_DIR})
  endif()

  include (deps/lpeg.cmake)
endif (WithLPEG)

if (WithZLIB)
  include(deps/zlib.cmake)
endif (WithZLIB)

add_definitions( -DLUVI_VERSION="${LUVI_VERSION}" )

if(WIN32)
  set(winsvc src/winsvc.h src/winsvcaux.h src/winsvc.c src/winsvcaux.c)
  if(WithSharedLibluv)
    add_definitions( -DLUA_BUILD_AS_DLL -DBUILDING_UV_SHARED )
  endif()
  add_definitions( -DWITH_WINSVC )
  add_definitions( -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS )

  add_library (luvi_renamed src/luvi_renamed.c)
endif()

if(UNIX)
  add_definitions(-Wall)
endif()

if (WITH_LUA_ENGINE STREQUAL Lua)
  add_definitions(-DWITH_PLAIN_LUA)
endif ()

if(LPEGLIB_DIR)
  set(lpeg_re_lua ${LPEGLIB_DIR}/re.lua)
endif()
lua_add_executable(luvi
  ${winsvc}
  src/main.c
  src/luvi_compat.c
  src/lua/init.lua
  src/lua/luvipath.lua
  src/lua/luvibundle.lua
  ${lpeg_re_lua}
)

if(APPLE)
  set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
  set(CMAKE_EXE_LINKER_FLAGS "-Wl,-E")
endif()

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  set(EXTRA_LIBS ${EXTRA_LIBS} rt)
endif()

target_link_libraries(luvi ${LUVI_LIBRARIES} ${EXTRA_LIBS} ${CMAKE_THREAD_LIBS_INIT})
set_target_properties(luvi PROPERTIES ENABLE_EXPORTS ON)

###############################################################################
## Installation Targets
###############################################################################

install(TARGETS luvi DESTINATION bin)

###############################################################################
## Packaging
###############################################################################

if(WithPackageSH OR WithPackageTGZ OR WithPackageTBZ2 OR WithPackageDEB
   OR WithPackageRPM OR WithPackageNSIS OR WithPackageBUNDLE)

  set(CPACK_PACKAGE_NAME "luvi")
  set(CPACK_PACKAGE_VENDOR "Luvit Authors")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A project in-between luv and luvit")
  set(CPACK_PACKAGE_VERSION "0.7.2")
  set(CPACK_PACKAGE_VERSION_MAJOR "0")
  set(CPACK_PACKAGE_VERSION_MINOR "7")
  set(CPACK_PACKAGE_VERSION_PATCH "2")
  set(CPACK_PACKAGE_INSTALL_DIRECTORY "luvi")
  set(CPACK_NSIS_MODIFY_PATH ON)

  unset(PACKAGE_LIST)
  if (WithPackageSH)
    list(APPEND CPACK_GENERATOR "STGZ")
    list(APPEND PACKAGE_LIST "Shell-installable package (.sh)")
  endif ()
  if (WithPackageTGZ)
    list(APPEND CPACK_GENERATOR "TGZ")
    list(APPEND PACKAGE_LIST "gziped tarball (.tar.gz)")
  endif ()
  if (WithPackageTBZ2)
    list(APPEND CPACK_GENERATOR "TBZ2")
    list(APPEND PACKAGE_LIST "bzip2'd tarball (.tar.bz2)")
  endif ()
  if (WithPackageDEB)
    list(APPEND CPACK_GENERATOR "DEB")
    list(APPEND PACKAGE_LIST "DEB package (.deb)")
    set(CPACK_DEBIAN_PACKAGE_SECTION "net")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Luvit Authors")
  endif ()
  if (WithPackageRPM)
    list(APPEND CPACK_GENERATOR "RPM")
    list(APPEND PACKAGE_LIST "RPM package (.rpm)")
    set(CPACK_RPM_PACKAGE_RELEASE 1)
    set(CPACK_RPM_PACKAGE_LICENSE "Apache 2")
  endif ()
  if (WithPackageNSIS)
    list(APPEND CPACK_GENERATOR "NSIS")
    list(APPEND PACKAGE_LIST "NSIS package (.exe)")
  endif ()
  if (WithPackageBUNDLE)
    list(APPEND CPACK_GENERATOR "Bundle")
    list(APPEND PACKAGE_LIST "OSX Bundle (.dmg)")
    set(CPACK_BUNDLE_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macosx/Info.plist)
    set(CPACK_BUNDLE_ICON ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macosx/Icons.icns)
    set(CPACK_BUNDLE_NAME "luvi")
  endif ()
  string(REPLACE ";" ", " PACKAGE_LIST "${PACKAGE_LIST}")

  include(CPack)
else()
  set(PACKAGE_LIST "None")
endif()
