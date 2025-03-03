if (WithSharedOpenSSL)
  find_package(OpenSSL REQUIRED)

  message("Enabling Shared OpenSSL")
  message("OPENSSL_INCLUDE_DIR: ${OPENSSL_INCLUDE_DIR}")
  message("OPENSSL_LIBRARIES:   ${OPENSSL_LIBRARIES}")
else (WithSharedOpenSSL)
  message("Enabling Static OpenSSL")

  execute_process(
    COMMAND openssl info -configdir
    OUTPUT_VARIABLE OPENSSL_CONFIG_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  set(OPENSSL_CONFIG_OPTIONS no-tests no-module no-shared no-pinshared no-makedepend --prefix=${CMAKE_BINARY_DIR})
  if (OPENSSL_CONFIG_DIR)
    message("Using existing OpenSSL configuration directory: ${OPENSSL_CONFIG_DIR}")
    set(OPENSSL_CONFIG_OPTIONS ${OPENSSL_CONFIG_OPTIONS} --openssldir=${OPENSSL_CONFIG_DIR})
  endif ()

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
    URL        https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz
    URL_HASH   SHA256=e15dda82fe2fe8139dc2ac21a36d4ca01d5313c75f99f46c4e8a27709b7294bf
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

  if (WIN32)
    set(OPENSSL_LIBRARIES ${OPENSSL_LIBRARIES} crypt32)
  endif ()

  message("OPENSSL_INCLUDE_DIR: ${OPENSSL_INCLUDE_DIR}")
  message("OPENSSL_LIBRARIES:   ${OPENSSL_LIBRARIES}")
endif (WithSharedOpenSSL)
