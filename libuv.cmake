include(CheckTypeSize)

cmake_minimum_required(VERSION 2.8)

set(LIBUVDIR ${CMAKE_SOURCE_DIR}/luv/libuv)

include_directories(
  ${LIBUVDIR}/include
  ${LIBUVDIR}/include/uv-private 
  ${LIBUVDIR}/src
)

set(SOURCES
  ${LIBUVDIR}/src/fs-poll.c
  ${LIBUVDIR}/src/inet.c
  ${LIBUVDIR}/src/uv-common.c
  ${LIBUVDIR}/src/version.c
)

if(WIN32)
  add_definitions(
    -DWIN32_LEAN_AND_MEAN
    -D_WIN32_WINNT=0x0600
    -D_CRT_SECURE_NO_WARNINGS
    -D_GNU_SOURCE
  )
  include_directories(${LIBUVDIR}/src/win)
  set(SOURCES ${SOURCES}
    ${LIBUVDIR}/src/win/async.c
    ${LIBUVDIR}/src/win/core.c
    ${LIBUVDIR}/src/win/dl.c
    ${LIBUVDIR}/src/win/error.c
    ${LIBUVDIR}/src/win/fs-event.c
    ${LIBUVDIR}/src/win/fs.c
    ${LIBUVDIR}/src/win/getaddrinfo.c
    ${LIBUVDIR}/src/win/handle.c
    ${LIBUVDIR}/src/win/loop-watcher.c
    ${LIBUVDIR}/src/win/pipe.c
    ${LIBUVDIR}/src/win/poll.c
    ${LIBUVDIR}/src/win/process-stdio.c
    ${LIBUVDIR}/src/win/process.c
    ${LIBUVDIR}/src/win/req.c
    ${LIBUVDIR}/src/win/signal.c
    ${LIBUVDIR}/src/win/stream.c
    ${LIBUVDIR}/src/win/tcp.c
    ${LIBUVDIR}/src/win/thread.c
    ${LIBUVDIR}/src/win/threadpool.c
    ${LIBUVDIR}/src/win/timer.c
    ${LIBUVDIR}/src/win/tty.c
    ${LIBUVDIR}/src/win/udp.c
    ${LIBUVDIR}/src/win/util.c
    ${LIBUVDIR}/src/win/winapi.c
    ${LIBUVDIR}/src/win/winsock.c)
else()
  include_directories(${LIBUVDIR}/src/unix)
  set(SOURCES ${SOURCES}
    ${LIBUVDIR}/src/unix/async.c
    ${LIBUVDIR}/src/unix/core.c
    ${LIBUVDIR}/src/unix/dl.c
    ${LIBUVDIR}/src/unix/error.c
    ${LIBUVDIR}/src/unix/fs.c
    ${LIBUVDIR}/src/unix/getaddrinfo.c
    ${LIBUVDIR}/src/unix/loop-watcher.c
    ${LIBUVDIR}/src/unix/loop.c
    ${LIBUVDIR}/src/unix/pipe.c
    ${LIBUVDIR}/src/unix/poll.c
    ${LIBUVDIR}/src/unix/process.c
    ${LIBUVDIR}/src/unix/proctitle.c
    ${LIBUVDIR}/src/unix/signal.c
    ${LIBUVDIR}/src/unix/stream.c
    ${LIBUVDIR}/src/unix/tcp.c
    ${LIBUVDIR}/src/unix/thread.c
    ${LIBUVDIR}/src/unix/threadpool.c
    ${LIBUVDIR}/src/unix/timer.c
    ${LIBUVDIR}/src/unix/tty.c
    ${LIBUVDIR}/src/unix/udp.c)
endif()

check_type_size("void*" SIZEOF_VOID_P)
if(SIZEOF_VOID_P EQUAL 8)
  add_definitions(-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE)
endif()

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  add_definitions(
    -D_GNU_SOURCE
  )
  set(SOURCES ${SOURCES}
    ${LIBUVDIR}/src/unix/linux-core.c
    ${LIBUVDIR}/src/unix/linux-syscalls.c
    ${LIBUVDIR}/src/unix/linux-inotify.c
  )
endif()

if(APPLE)
  add_definitions(
    -D=_DARWIN_USE_64_BIT_INODE
  )
  set(SOURCES ${SOURCES}
    ${LIBUVDIR}/src/unix/darwin.c
    ${LIBUVDIR}/src/unix/fsevents.c
    ${LIBUVDIR}/src/unix/kqueue.c
    ${LIBUVDIR}/src/unix/darwin-proctitle.c
  )
endif()

add_library(libuv ${SOURCES})

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  target_link_libraries(libuv
    pthread
  )
endif()

if(WIN32)
  target_link_libraries(libuv
    ws2_32.lib
    shell32.lib
    psapi.lib
    iphlpapi.lib
    advapi32.lib
  )
endif()

if(APPLE)
  find_library(FOUNDATION_LIBRARY Foundation)
  find_library(CORESERVICES_LIBRARY CoreServices)
  find_library(APPLICATION_SERVICES_LIBRARY ApplicationServices)
  target_link_libraries(libuv
    ${FOUNDATION_LIBRARY}
    ${CORESERVICES_LIBRARY}
    ${APPLICATION_SERVICES_LIBRARY}
  )
endif()
