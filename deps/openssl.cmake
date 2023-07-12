if (WithSharedOpenSSL)
  find_package(OpenSSL REQUIRED)

  message("OpenSSL include dir: ${OPENSSL_INCLUDE_DIR}")
  message("OpenSSL libraries: ${OPENSSL_LIBRARIES}")

  include_directories( ${OPENSSL_INCLUDE_DIR} )
  link_directories( ${OPENSSL_ROOT_DIR}/lib )
  list(APPEND LIB_LIST ${OPENSSL_LIBRARIES})
else (WithSharedOpenSSL)
  message("Enabling Static OpenSSL")
  include(ExternalProject)

  set(OPENSSL_CONFIG_OPTIONS no-unit-test no-shared no-stdio no-idea no-mdc2 no-rc5 --prefix=${CMAKE_BINARY_DIR})
  if(NOT WithOpenSSLASM)
    set(OPENSSL_CONFIG_OPTIONS no-asm ${OPENSSL_CONFIG_OPTIONS})
  endif()

  if(WIN32)
    if (CMAKE_CROSSCOMPILING)
      if("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "AMD64")
        set(OPENSSL_CONFIGURE_COMMAND CONFIGURE_INSIST=1 perl ./Configure mingw64 ${OPENSSL_CONFIG_OPTIONS})
      else()
        set(OPENSSL_CONFIGURE_COMMAND CONFIGURE_INSIST=1 perl ./Configure mingw ${OPENSSL_CONFIG_OPTIONS})
      endif()
      
      set(OPENSSL_BUILD_COMMAND make $ENV{MAKEFLAGS})
    else()
      if("${CMAKE_GENERATOR_PLATFORM}" MATCHES "x64")
        set(OPENSSL_CONFIGURE_COMMAND perl ./Configure VC-WIN64A ${OPENSSL_CONFIG_OPTIONS})
      else()
        set(OPENSSL_CONFIGURE_COMMAND perl ./Configure VC-WIN32 ${OPENSSL_CONFIG_OPTIONS})
      endif()
      
      set(OPENSSL_BUILD_COMMAND nmake)
    endif()
  else()
    if (CMAKE_CROSSCOMPILING)
      # This is an attempt to start cross compiling support for openssl.
      if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
        set(OPENSSL_CONFIGURE_TARGET linux-${CMAKE_SYSTEM_PROCESSOR})
      elseif("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
        set(OPENSSL_CONFIGURE_TARGET darwin64-${CMAKE_SYSTEM_PROCESSOR})
      endif()

      set(OPENSSL_CONFIGURE_COMMAND perl ./Configure ${OPENSSL_CONFIGURE_TARGET} ${OPENSSL_CONFIG_OPTIONS})
    else()
      # ./config does target autodetection
      set(OPENSSL_CONFIGURE_COMMAND perl config ${OPENSSL_CONFIG_OPTIONS})
    endif()

    # Note: We don't pass any of the flags that are passed to cmake into openssl.
    set(OPENSSL_BUILD_COMMAND make $ENV{MAKEFLAGS})
  endif()

  if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
  endif()

  set(OPENSSL_SOURCE https://www.openssl.org/source/openssl-1.1.1m.tar.gz)
  set(OPENSSL_SOURCE_HASH f89199be8b23ca45fc7cb9f1d8d3ee67312318286ad030f5316aca6462db6c96)
  if(DEFINED ENV{OPENSSL_SOURCE})
    set(OPENSSL_SOURCE $ENV{OPENSSL_SOURCE})
  endif()

  if(DEFINED ENV{OPENSSL_SOURCE_HASH})
    set(OPENSSL_SOURCE_HASH $ENV{OPENSSL_SOURCE_HASH})
  endif()

  ExternalProject_Add(openssl
      PREFIX            openssl
      URL               ${OPENSSL_SOURCE}
      URL_HASH          SHA256=${OPENSSL_SOURCE_HASH}
      DOWNLOAD_NO_PROGRESS ON
      LOG_BUILD         ON
      BUILD_IN_SOURCE   YES
      BUILD_COMMAND     ${OPENSSL_BUILD_COMMAND}
      CONFIGURE_COMMAND ${OPENSSL_CONFIGURE_COMMAND}
      INSTALL_COMMAND   ""
      TEST_COMMAND      ""
  )

  set(OPENSSL_DIR ${CMAKE_BINARY_DIR}/openssl/src/openssl)
  set(OPENSSL_INCLUDE ${OPENSSL_DIR}/include)

  if(WIN32)
    set(OPENSSL_LIB_CRYPTO ${OPENSSL_DIR}/libcrypto.lib)
    set(OPENSSL_LIB_SSL ${OPENSSL_DIR}/libssl.lib)
  else()
    set(OPENSSL_LIB_CRYPTO ${OPENSSL_DIR}/libcrypto.a)
    set(OPENSSL_LIB_SSL ${OPENSSL_DIR}/libssl.a)
  endif()

  add_library(openssl_ssl STATIC IMPORTED)
  set_target_properties(openssl_ssl PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIB_SSL})
  add_library(openssl_crypto STATIC IMPORTED)
  set_target_properties(openssl_crypto PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIB_CRYPTO})

  include_directories(${OPENSSL_INCLUDE})
  list(APPEND LIB_LIST openssl_ssl openssl_crypto)
endif (WithSharedOpenSSL)

add_definitions(-DWITH_OPENSSL)
include(deps/lua-openssl.cmake)

