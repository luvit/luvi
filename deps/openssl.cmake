if (WithSharedOpenSSL)
  find_package(OpenSSL REQUIRED)

  message("OpenSSL include dir: ${OPENSSL_INCLUDE_DIR}")
  message("OpenSSL libraries: ${OPENSSL_LIBRARIES}")

  include_directories(${OPENSSL_INCLUDE_DIR})
  link_directories(${OPENSSL_ROOT_DIR}/lib)
  list(APPEND LIB_LIST ${OPENSSL_LIBRARIES})
else (WithSharedOpenSSL)
  message("Enabling Static OpenSSL")
  include(ExternalProject)

  set(OPENSSL_CONFIG_OPTIONS no-unit-test no-shared no-asm no-stdio no-idea no-mdc2 no-rc5 --prefix=${CMAKE_BINARY_DIR})
  set(OPENSSL_BUILD_COMMAND ${MAKE})

  if(WIN32)
      if("${CMAKE_GENERATOR}" MATCHES "(Win64|IA64)")
        set(OPENSSL_CONFIGURE_COMMAND perl ./Configure VC-WIN64A ${OPENSSL_CONFIG_OPTIONS})
      else()
        set(OPENSSL_CONFIGURE_COMMAND perl ./Configure VC-WIN32 ${OPENSSL_CONFIG_OPTIONS})
      endif()
  else()
      set(OPENSSL_CONFIGURE_COMMAND ./config ${OPENSSL_CONFIG_OPTIONS})
  endif()
  
  ExternalProject_Add(openssl
      PREFIX            openssl
      URL               https://www.openssl.org/source/openssl-1.1.0i.tar.gz
      URL_HASH          SHA256=ebbfc844a8c8cc0ea5dc10b86c9ce97f401837f3fa08c17b2cdadc118253cf99
      BUILD_IN_SOURCE   YES
      BUILD_COMMAND     ${OPENSSL_BUILD_COMMAND}
      CONFIGURE_COMMAND ${OPENSSL_CONFIGURE_COMMAND}
      INSTALL_COMMAND   ""
      TEST_COMMAND      ""
      UPDATE_COMMAND    ""
      UPDATE_DISCONNECTED YES
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

