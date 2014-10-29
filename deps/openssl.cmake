if (WithSharedOpenSSL)
  find_package(OpenSSL REQUIRED)

  message("OpenSSL include dir: ${OPENSSL_INCLUDE_DIR}")
  message("OpenSSL libraries: ${OPENSSL_LIBRARIES}")

  include_directories(${OPENSSL_INCLUDE_DIR})
  link_directories(${OPENSSL_ROOT_DIR}/lib)
  list(APPEND LIB_LIST ${OPENSSL_LIBRARIES})
else (WithSharedOpenSSL)
  message("Enabling Static OpenSSL")
  include(deps/openssl/openssl.cmake)
  list(APPEND LIB_LIST openssl)
endif (WithSharedOpenSSL)

add_definitions(-DWITH_OPENSSL)
include(deps/lua-openssl.cmake)

