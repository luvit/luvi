cmake_minimum_required(VERSION 3.15)

project(luvi C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")

if (MSVC)
  cmake_policy(SET CMP0091 NEW)
  # Statically build against C runtime (use the right version for Release/Debug)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif ()

if (CMAKE_COMPILER_IS_GNUCC)
  add_compile_options(-Wno-unused-function)
endif ()

if (MINGW)
  add_compile_options(-Wno-error=incompatible-pointer-types)
endif ()

if (UNIX)
  add_compile_options(-Wall)
endif ()

if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
  file (STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" LUVI_VERSION)
  message("-- Found luvi version: ${LUVI_VERSION}")
else ()
  execute_process(
    COMMAND git describe --tags
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE LUVI_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  # Handle shallow clones
  if (LUVI_VERSION STREQUAL "")
    execute_process(
      COMMAND git rev-parse --short HEAD
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE LUVI_VERSION
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    set(LUVI_VERSION "v0.0.0-0-g${LUVI_VERSION}")
  endif ()
  message("-- Found luvi git version: ${LUVI_VERSION}")
endif ()

option(WithSharedLibluv "Shared or Static libluv" OFF)
option(WithOpenSSL "Include OpenSSL" OFF)
option(WithOpenSSLASM "Enable Assembly Optimizations" ON)
option(WithSharedOpenSSL "Shared or Static OpenSSL" OFF)
option(WithPCRE "Include PCRE" OFF)
option(WithSharedPCRE "Shared or Static PCRE" OFF)
option(WithLPEG "Include LPEG" OFF)
option(WithSharedLPEG "Shared or Static LPEG" OFF)
option(WithZLIB "Include ZLIB" OFF)
option(WithSharedZLIB "Shared or Static ZLIB" OFF)

find_package(Threads)
set (LUVI_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})

# When linking against a shared libluv, we assume that luajit and libuv are also shared
# Luvi does not support linking a static libluv *and* a static lua/luajit or libuv
if (WithSharedLibluv)
  find_package(Libluv REQUIRED)
  include_directories(${LIBLUV_INCLUDE_DIR})

  find_package(LuaJIT  REQUIRED)
  include_directories(${LUAJIT_INCLUDE_DIR})

  find_package(Libuv  REQUIRED)
  include_directories(${LIBUV_INCLUDE_DIR})

  list(APPEND LUVI_LIBRARIES ${LIBLUV_LIBRARIES} ${LUAJIT_LIBRARIES} ${LIBUV_LIBRARIES})
else (WithSharedLibluv)
  # Build luv as static library instead of as module
  set(BUILD_MODULE OFF CACHE BOOL "Turn off building luv as module")
  set(BUILD_STATIC_LIBS ON CACHE BOOL "Build luv as static lib")
  include_directories(deps/luv/src)
  include_directories(deps/luv/deps/libuv/include)
  if (WITH_LUA_ENGINE STREQUAL Lua)
    include_directories(deps/luv/deps/lua)
    list(APPEND LUVI_LIBRARIES lualib)
  else ()
    include_directories(deps/luv/deps/luajit/src)
    list(APPEND LUVI_LIBRARIES luajit-5.1)
  endif ()

  list(APPEND LUVI_LIBRARIES libluv_a uv_a)
  add_subdirectory(deps/luv) # Build luv
endif (WithSharedLibluv)

set(LUA_COMPAT53_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/luv/deps/lua-compat-5.3" CACHE PATH "Path to lua-compat-5.3")
include_directories(${LUA_COMPAT53_DIR})
include_directories(${LUA_COMPAT53_DIR}/c-api)

if (WithOpenSSL)
  include(deps/lua-openssl.cmake)
endif ()

if (WithPCRE)
  include(deps/lrexlib.cmake)
endif ()

if (WithLPEG)
  include(deps/lpeg.cmake)
  set(lpeg_re_lua ${LPEGLIB_DIR}/re.lua)
endif ()

if (WithZLIB)
  include(deps/lua-zlib.cmake)
endif ()

if (WIN32)
  set(winsvc src/winsvc.h src/winsvcaux.h src/winsvc.c src/winsvcaux.c)
  if (WithSharedLibluv)
    add_definitions( -DLUA_BUILD_AS_DLL -DBUILDING_UV_SHARED )
  endif ()
  add_definitions( -DWITH_WINSVC )
  add_definitions( -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS )

  add_library (luvi_renamed src/luvi_renamed.c)
endif ()

if (WITH_LUA_ENGINE STREQUAL Lua)
  add_definitions(-DWITH_PLAIN_LUA)
endif ()

include(LuaAddExecutable)
lua_add_executable(luvi
  ${winsvc}
  src/main.c
  src/luvi_compat.c
  src/lua/init.lua
  src/lua/luvipath.lua
  src/lua/luvibundle.lua
  ${lpeg_re_lua}
)

if (${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
  set(CMAKE_EXE_LINKER_FLAGS "-Wl,-E")
endif ()

if (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  set(list APPEND LUVI_LIBRARIES rt)
endif ()

target_link_libraries(luvi ${LUVI_LIBRARIES} ${EXTRA_LIBS})
set_target_properties(luvi PROPERTIES ENABLE_EXPORTS ON)

target_compile_definitions(luvi PRIVATE LUVI_VERSION="${LUVI_VERSION}")
target_compile_definitions(luvi PRIVATE ${LUVI_DEFINITIONS}) # Add any extra definitions, like the WITH_{LIB} defines

message("Configuration Summary:")
message("  LUVI_VERSION: ${LUVI_VERSION}")
message("  LUVI_DEFINITIONS: ${LUVI_DEFINITIONS}")
message("  LUVI_LIBRARIES: ${LUVI_LIBRARIES}")

###############################################################################
## Installation Targets
###############################################################################

install(TARGETS luvi DESTINATION bin)
