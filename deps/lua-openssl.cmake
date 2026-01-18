include(deps/openssl.cmake)

set(LUA_OPENSSL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-openssl" CACHE PATH "Path to lua-openssl")

include_directories(
  ${CMAKE_BINARY_DIR}/include
  ${LUA_OPENSSL_DIR}/deps/auxiliar
  ${LUA_OPENSSL_DIR}/deps/lua-compat
  ${LUA_OPENSSL_DIR}/src
)

if(WIN32)
  add_compile_definitions(WIN32_LEAN_AND_MEAN)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
else()
  find_package(Threads)
endif()

add_library(lua_openssl STATIC
  ${LUA_OPENSSL_DIR}/deps/auxiliar/auxiliar.c
  ${LUA_OPENSSL_DIR}/deps/auxiliar/subsidiar.c
  ${LUA_OPENSSL_DIR}/src/asn1.c
  ${LUA_OPENSSL_DIR}/src/bio.c
  ${LUA_OPENSSL_DIR}/src/callback.c
  ${LUA_OPENSSL_DIR}/src/cipher.c
  ${LUA_OPENSSL_DIR}/src/cms.c
  ${LUA_OPENSSL_DIR}/src/compat.c
  ${LUA_OPENSSL_DIR}/src/crl.c
  ${LUA_OPENSSL_DIR}/src/csr.c
  ${LUA_OPENSSL_DIR}/src/dh.c
  ${LUA_OPENSSL_DIR}/src/digest.c
  ${LUA_OPENSSL_DIR}/src/dsa.c
  ${LUA_OPENSSL_DIR}/src/ec.c
  ${LUA_OPENSSL_DIR}/src/engine.c
  ${LUA_OPENSSL_DIR}/src/hmac.c
  ${LUA_OPENSSL_DIR}/src/kdf.c
  ${LUA_OPENSSL_DIR}/src/lbn.c
  ${LUA_OPENSSL_DIR}/src/lhash.c
  ${LUA_OPENSSL_DIR}/src/mac.c
  ${LUA_OPENSSL_DIR}/src/misc.c
  ${LUA_OPENSSL_DIR}/src/ocsp.c
  ${LUA_OPENSSL_DIR}/src/oids.txt
  ${LUA_OPENSSL_DIR}/src/openssl.c
  ${LUA_OPENSSL_DIR}/src/ots.c
  ${LUA_OPENSSL_DIR}/src/param.c
  ${LUA_OPENSSL_DIR}/src/pkcs12.c
  ${LUA_OPENSSL_DIR}/src/pkcs7.c
  ${LUA_OPENSSL_DIR}/src/pkey.c
  ${LUA_OPENSSL_DIR}/src/private.h
  ${LUA_OPENSSL_DIR}/src/provider.c
  ${LUA_OPENSSL_DIR}/src/rsa.c
  ${LUA_OPENSSL_DIR}/src/sk.h
  ${LUA_OPENSSL_DIR}/src/srp.c
  ${LUA_OPENSSL_DIR}/src/ssl.c
  ${LUA_OPENSSL_DIR}/src/th-lock.c
  ${LUA_OPENSSL_DIR}/src/util.c
  ${LUA_OPENSSL_DIR}/src/x509.c
  ${LUA_OPENSSL_DIR}/src/xalgor.c
  ${LUA_OPENSSL_DIR}/src/xattrs.c
  ${LUA_OPENSSL_DIR}/src/xexts.c
  ${LUA_OPENSSL_DIR}/src/xname.c
  ${LUA_OPENSSL_DIR}/src/xstore.c
)

target_include_directories(lua_openssl PUBLIC ${OPENSSL_INCLUDE_DIR})
target_link_libraries(lua_openssl ${OPENSSL_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})

list(APPEND LUVI_LIBRARIES lua_openssl ${OPENSSL_LIBRARIES})
list(APPEND LUVI_DEFINITIONS WITH_OPENSSL=1)
