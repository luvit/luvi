set(LUA_OPENSSL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-openssl)

include_directories(
  ${LUA_OPENSSL_DIR}/deps
  ${LUA_OPENSSL_DIR}/src
)

add_definitions(
  -DCOMPAT52_IS_LUAJIT
)

add_library(lua_openssl
  ${LUA_OPENSSL_DIR}/src/asn1.c                       
  ${LUA_OPENSSL_DIR}/src/auxiliar.c                   
  ${LUA_OPENSSL_DIR}/src/bio.c                        
  ${LUA_OPENSSL_DIR}/src/callback.c                     
  ${LUA_OPENSSL_DIR}/src/cipher.c                     
  ${LUA_OPENSSL_DIR}/src/cms.c                        
  ${LUA_OPENSSL_DIR}/src/crl.c                        
  ${LUA_OPENSSL_DIR}/src/csr.c                        
  ${LUA_OPENSSL_DIR}/src/dh.c                         
  ${LUA_OPENSSL_DIR}/src/digest.c                     
  ${LUA_OPENSSL_DIR}/src/dsa.c                        
  ${LUA_OPENSSL_DIR}/src/ec.c                         
  ${LUA_OPENSSL_DIR}/src/engine.c                     
  ${LUA_OPENSSL_DIR}/src/hmac.c                       
  ${LUA_OPENSSL_DIR}/src/lbn.c                        
  ${LUA_OPENSSL_DIR}/src/lhash.c                      
  ${LUA_OPENSSL_DIR}/src/misc.c                       
  ${LUA_OPENSSL_DIR}/src/ocsp.c                       
  ${LUA_OPENSSL_DIR}/src/oids.txt                     
  ${LUA_OPENSSL_DIR}/src/openssl.c                    
  ${LUA_OPENSSL_DIR}/src/ots.c                        
  ${LUA_OPENSSL_DIR}/src/pkcs12.c                     
  ${LUA_OPENSSL_DIR}/src/pkcs7.c                      
  ${LUA_OPENSSL_DIR}/src/pkey.c                       
  ${LUA_OPENSSL_DIR}/src/private.h                    
  ${LUA_OPENSSL_DIR}/src/rsa.c                        
  ${LUA_OPENSSL_DIR}/src/sk.h                         
  ${LUA_OPENSSL_DIR}/src/ssl.c                        
  ${LUA_OPENSSL_DIR}/src/th-lock.c                    
  ${LUA_OPENSSL_DIR}/src/util.c                       
  ${LUA_OPENSSL_DIR}/src/x509.c                       
  ${LUA_OPENSSL_DIR}/src/xattrs.c                     
  ${LUA_OPENSSL_DIR}/src/xexts.c                      
  ${LUA_OPENSSL_DIR}/src/xname.c                      
  ${LUA_OPENSSL_DIR}/src/xstore.c                     
)

if (WithSharedOpenSSL)
  target_link_libraries(lua_openssl ssl crypto)
else (WithSharedOpenSSL)
  target_link_libraries(lua_openssl openssl)
endif (WithSharedOpenSSL)

set(EXTRA_LIBS ${EXTRA_LIBS} lua_openssl)
