if (WithSharedOpenSSL)
  find_package(OpenSSL REQUIRED)

  message("Enabling Shared OpenSSL")
  message("OPENSSL_INCLUDE_DIR: ${OPENSSL_INCLUDE_DIR}")
  message("OPENSSL_LIBRARIES:   ${OPENSSL_LIBRARIES}")
else (WithSharedOpenSSL)
  message("Enabling Static OpenSSL")

  set(OPENSSL_CONFIG_OPTIONS no-unit-test no-shared no-stdio no-idea no-mdc2 no-rc5 --prefix=${CMAKE_BINARY_DIR})
  if (WithOpenSSLASM)
    enable_language(ASM)
    if (MSVC)
      enable_language(ASM_NASM)
    endif ()
  else ()
    set(OPENSSL_CONFIG_OPTIONS no-asm ${OPENSSL_CONFIG_OPTIONS})
  endif ()

  set(OPENSSL_CONFIGURE_TARGET)
  set(OPENSSL_BUILD_COMMAND make)
  if (WIN32)
    if (MSVC)
      set(OPENSSL_CONFIGURE_TARGET VC-WIN32)
      if ("${CMAKE_VS_PLATFORM_NAME}" MATCHES "x64")
        set(OPENSSL_CONFIGURE_TARGET VC-WIN64A)
      endif ()
      set(OPENSSL_BUILD_COMMAND nmake)
    elseif (MINGW)
      set(OPENSSL_CONFIGURE_TARGET mingw)
      if ("${CMAKE_SIZEOF_VOID_P}" EQUAL "8")
        set(OPENSSL_CONFIGURE_TARGET mingw64)
      endif ()

      set(OPENSSL_BUILD_COMMAND mingw32-make)
    else ()
      # TODO: Add support for other Windows compilers
      message(FATAL_ERROR "This platform does not support building OpenSSL")
    endif ()
  endif ()

  message("OPENSSL_CONFIGURE_TARGET: ${OPENSSL_CONFIGURE_TARGET}")
  message("OPENSSL_CONFIG_OPTIONS: ${OPENSSL_CONFIG_OPTIONS}")
  message("OPENSSL_BUILD_COMMAND: ${OPENSSL_BUILD_COMMAND}")
  include(FetchContent)

  FetchContent_Declare(openssl
    URL        https://github.com/openssl/openssl/releases/download/openssl-3.0.14/openssl-3.0.14.tar.gz
    URL_HASH   SHA256=eeca035d4dd4e84fc25846d952da6297484afa0650a6f84c682e39df3a4123ca
  )

  FetchContent_MakeAvailable(openssl)
  FetchContent_GetProperties(openssl)

  set(OPENSSL_ROOT_DIR ${openssl_SOURCE_DIR})

  # Configure OpenSSL

  execute_process(
    COMMAND perl Configure ${OPENSSL_CONFIGURE_TARGET} ${OPENSSL_CONFIG_OPTIONS}
    WORKING_DIRECTORY ${OPENSSL_ROOT_DIR}
    RESULT_VARIABLE result
  )

  if (result)
    message(FATAL_ERROR "Failed to configure OpenSSL")
  endif ()

  execute_process(
    COMMAND perl configdata.pm --dump
    WORKING_DIRECTORY ${OPENSSL_ROOT_DIR}
  )
  
  if (MSVC)
    set(OPENSSL_LIB_CRYPTO ${OPENSSL_ROOT_DIR}/libcrypto.lib)
    set(OPENSSL_LIB_SSL ${OPENSSL_ROOT_DIR}/libssl.lib)
  else ()
    set(OPENSSL_LIB_CRYPTO ${OPENSSL_ROOT_DIR}/libcrypto.a)
    set(OPENSSL_LIB_SSL ${OPENSSL_ROOT_DIR}/libssl.a)
  endif ()

  # Build OpenSSL

  add_custom_target(openssl-build
    COMMAND ${OPENSSL_BUILD_COMMAND}
    BYPRODUCTS ${OPENSSL_LIB_CRYPTO} ${OPENSSL_LIB_SSL}
    WORKING_DIRECTORY ${OPENSSL_ROOT_DIR}
    USES_TERMINAL
  )

  # Define OpenSSL libraries

  add_library(openssl_ssl STATIC IMPORTED)
  set_target_properties(openssl_ssl PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIB_SSL})
  add_dependencies(openssl_ssl openssl-build)

  add_library(openssl_crypto STATIC IMPORTED)
  set_target_properties(openssl_crypto PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIB_CRYPTO})
  add_dependencies(openssl_ssl openssl-build)

  set(OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT_DIR}/include)
  set(OPENSSL_LIBRARIES openssl_ssl openssl_crypto)

  message("OPENSSL_INCLUDE_DIR: ${OPENSSL_INCLUDE_DIR}")
  message("OPENSSL_LIBRARIES:   ${OPENSSL_LIBRARIES}")
endif (WithSharedOpenSSL)
