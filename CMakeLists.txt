cmake_minimum_required(VERSION 2.8.9)

project(luvi C)

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

exec_program(
    "git"
    ${CMAKE_CURRENT_SOURCE_DIR}
    ARGS "describe" "--tags"
    OUTPUT_VARIABLE LUVI_VERSION)

option(WithOpenSSL "Include OpenSSL" OFF)
option(WithSharedOpenSSL "Shared or Static OpenSSL" ON)
option(WithZLIB "Include ZLIB" OFF)
option(WithSharedZLIB "Shared or Static ZLIB" ON)
option(WithPackageSH "Build shell-installable package." OFF)
option(WithPackageTGZ "Build gziped tarball package." OFF)
option(WithPackageTBZ2 "Build bzip2'd tarball package." OFF)
option(WithPackageDEB "Build DEB package." OFF)
option(WithPackageRPM "Build RPM package." OFF)
option(WithPackageNSIS "Build NSIS package." OFF)
option(WithPackageBUNDLE "Build OSX bundle." OFF)

include(deps/luv/deps/luajit.cmake)
include(deps/luv/deps/uv.cmake)

if (WithOpenSSL)
  include(deps/openssl.cmake)
  add_definitions( -DWITH_OPENSSL )
endif (WithOpenSSL)

if (WithZLIB)
  include(deps/zlib.cmake)
  add_definitions( -DWITH_ZLIB )
endif (WithZLIB)

add_definitions( -DLUVI_VERSION="${LUVI_VERSION}" )

if(MSVC)
  set(winsvc src/winsvc.h src/winsvcaux.h src/winsvc.c src/winsvcaux.c)
  add_definitions( -DWITH_WINSVC -DLUA_BUILD_AS_DLL -DLUA_LIB -DBUILDING_UV_SHARED )
endif()

if(UNIX)
  add_definitions(-Wall)
endif()

luajit_add_executable(luvi
  ${winsvc}
  src/main.c
  src/lua/init.lua
)

if(APPLE)
  set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
  set(CMAKE_EXE_LINKER_FLAGS "-Wl,-E")
endif()

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  target_link_libraries(luvi uv lua51 rt ${EXTRA_LIBS})
else()
  target_link_libraries(luvi uv lua51 ${EXTRA_LIBS})
endif()

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
