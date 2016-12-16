# Luvi Changelog

High-level changes between release versions.

## v2.7.6

 - luv: Update to 1.9.1-1 (Tim Caswell)
   - Fix upstream lua submodule (Tim Caswell)
   - Fix crash when handles are nil (Ryan Phillips)
   - Fix compile for VS2008 (zhangtj)
 - miniz: Fix expansion warnings (Jörg Krause)
 - openssl: Bump to 1.0.2h (Ryan Phillips)

## v2.7.5

 - luv: Don't free luv_handle_t till after parent is GCed [Tim Caswell]

## v2.7.4

 - luv: Update luv [Tim Caswell]
 - luajit: Update to latest in 2.1 branch. [Tim Caswell]

## v2.7.2

 - openssl: update to 1.0.2g with working assembly. [Ryan Phillips]

## v2.7.1

 - openssl: revert to 1.0.2e [Tim Caswell]
 - lua-openssl: revert to C_HAPPY-14-g6e96296 [Tim Caswell]
 - luv: update to 1.9.0-3 to get memory leak fixes [Tim Caswell]

## v2.7.0

 - openssl: update to 1.0.2g [Ryan Phillips]
 - lua-openssl: update submodule [Tim Caswell]
 - luv: update to 1.9.0-1 [Tim Caswell]
 - libuv: update to v1.9.0 [Tim Caswell]
 - luvi: make compatible with plain Lua 5.2 or 5.3 [Xavier Wang]

## v2.6.1

 - luv: bump luv for a 32bit compile fix [Ryan Phillips]

## v2.6.0

 - luv: bump luv to Luajit 2.1 (fixes 64bit casts on Windows) [Ryan Phillips]
 - versions: make the winsvc module export a valid semver version [Ryan Phillips]

## v2.5.2

 - luvi: Fix auto-require logic to not require `luvit/require` [Tim Caswell]
 - lua: Update test lua to 5.3.2 [Tim Caswell]

## v2.5.1

 - luvi: Don't constantly update timestamps when creating zips. [Tim Caswell]
 - libuv: Update to v1.8.0 [Tim Caswell]
 - luv: Add uv.fs_realpath [Tim Caswell]
 - luv: add netmask to network interface data [George Zhao]

## v2.5.0

 - luvi: allow preloading a custom module [George Zhao]
 - luvi: bump lua-openssl [Jörg Krause]
 - luvi: set RPATH within CMake [Jörg Krause]
 - luvi: allow the settings of Luajit bytecode options [Jörg Krause]
 - luvi: bump openssl to 1.0.2e [Ryan Phillips]
 - luvi: holy build support [Ryan Phillips]

## v2.4.0

 - luvi: Added new "snapshot" module to help debug memory leaks. [Tim Caswell]
 - luv: Add bindings for `uv_get_free_memory`. [Tim Caswell]
 - luv: Export libuv symbols when linking without shared libuv. [mythay]
 - luv: Fix linking lua lib name without standard name in windows. [mythay]

## v2.3.5

 - libuv: Update to v1.7.5 [Tim Caswell]
 - luv: Export `luv_loop()` and `luv_state()` [Tim Caswell]

## v2.3.4

 - libuv: Update to v1.7.4 [Tim Caswell]

## v2.3.3

 - libuv: Update to v1.7.3 [Tim Caswell]
 - luv: Many fixes and improvements to thread bindings [George Zhao]

## v2.3.2

 - libuv: Update libuv to v1.7.2 [Tim Caswell]
 - luv: Performance tweaks and memory leak fixes for threads [George Zhao]
 - luvi: Add proper thread linking for luajit [Ryan Phillips]

## v2.3.1

 - luvi: Fix isWindows check to work in threads too. [Tim Caswell]

## v2.3.0

 - Factor out path and bundle libraries to "luvipath" and "luvibundle" [Tim Caswell]
 - luv: Add a "mac" field to the luv_interface_addresses() [Brian Maher]
 - luv: Fix bug when set thread acquire/release vm callback [George Zhao]
 - luv: Update libuv to v1.7.1 [Tim Caswell]
 - luv: Improve error message in tcp.c and udp.c [Ryan Phillips]
 - Use luv_set_thread_cb for better thread support [George Zhao]
 - Use os.getenv for portable read-only access to environment variables [Tim Caswell]
 - Don't depend in luajit ffi to detect windows [Tim Caswell]

## v2.2.0

 - Added lpeg to regular build [George Zhao]
 - libuv: update to v1.7.0 [Tim Caswell]

## v2.1.8

 - miniz: Fix CRC32 to be compatible with other zip tools. [Tim Caswell]
 - luvi: Change published zip to include name for homebrew. [Tim Caswell]

## v2.1.7

 - luvi: Add rex module (PCRE via lrexlib) to regular build [Tim Caswell]
 - luv: Fix to build with Visual Studio 14 (2015) / Windows 10 [Tim Caswell]
 - lua-openssl: Update to pull in many bugfixes [Tim Caswell]

## v2.1.6

 - luv: Fix GC bug where uv.spawn would sometimes segfault [Ryan Phillips]
 - luvi: Add libuv version to version table [Ryan Phillips]

## v2.1.5

 - luv: Add stack traces for uncaught errors. [Tim Caswell]
 - openssl: Update to v1.0.2d. [Ryan Phillips]

## v2.1.4

 - lua-openssl/openssl: Really fix session reuse [Ryan Phillips]

## v2.1.3

 - openssl: Fix openssl asm build on windows [Ryan Phillips]

## v2.1.2

 - openssl: Bump version to 1.0.2c [Ryan Phillips]
 - openssl: Add asm support for improved performance [Ryan Phillips]
 - lua-openssl: Update to enable session reuse [Ryan Phillips]
 - luvi: Allow using luvi in shebang lines [Tim Caswell]
 - libuv: Update to 1.6.1 [Tim Caswell]

## v2.1.1

 - openssl: Bump version to 1.0.2b [Ryan Phillips]
 - lua-openssl: Update to master [Tim Caswell]

## v2.1.0

 - libuv: Update to v1.6.0 release. [Tim Caswell]
 - luv: Add uv.os_homedir() function. [Tim Caswell]
 - luv: Add uv.new_socket_poll() function. [runner.mei]
 - luv: Fix(fs_lstat, enable S_IFLNK [Brian Maher]
 - lua-openssl: Update to latest. [Ryan Phillips]

## v2.0.9

 - luajit: Update to v2.0.4 release.

## v2.0.7

 - lua-openssl: Support SNI [George Zhao]

## v2.0.6

 - libuv: Update to v1.5.0 [Tim Caswell]
 - luvi: Go back to release builds [Ryan Phillips]

## v2.0.5

 - luvi: Bump lua-openssl for signature verification improvements [Ryan Phillips]
 - luvi: Documentation tweak in README [Lionel Duboeuf]

## v2.0.4

 - luvi: When require is bootstrapped, load main in it's environment. [Tim Caswell]
 - luv: Remove printf in luv_status [Ryan Phillips]

## v2.0.3

 - luvi: Expose `bundle.mainPath` and `bundle.paths` [Tim Caswell]
 - luvi: Fix `bundle.readfile` for BSD. [Tim Caswell]

## v2.0.2

 - luvi: Add back custom main as a command-line flag `-m` [Tim Caswell]
 - luv: Merge uv.new_thread with uv.create_thread. [Tim Caswell]

## v2.0.1

 - luajit: Go back to stable 2.0.3 version [Tim Caswell]

## v2.0.0

 - luvi: Major change in interface to use command-line args instead of
     environment variables. [Tim Caswell]
 - libuv: Update to latest in v1.x branch. [Tim Caswell]
 - luajit: Switch to v2.1 branch. [Tim Caswell]
 - luv: Add threading support [George Zhao]
 - lua-openssl: Update to latest upstream. [Tim Caswell]
 - openssl: Fix build for arm devices [Ryan Phillips]
 - luvi: Add string lua 5.3 compat apis, pack,unpack,packsize [George Zhao]

## v1.1.0

 - luv: Hard exit on uncaught exceptions in event callbacks [Tim Caswell]
 - luv: Remove fprintf for errors. [Ryan Phillips]
 - luv: Fix bug in fs_event_start callback. [George Zhao]
 - luvi: Match lower-case drive letters on windows [Tim Caswell]
 - luvi: No longer include zlib bindings in default build [Tim Caswell]
 - luvi: Drop "large" build and rename "static" to "regular" [Tim Caswell]

## v1.0.1

 - lua-openssl: Update to latest [Ryan Phillips]
 - openssl: Update to 1.0.2a [Ryan Phillips]
 - luv: Fix spawn memory leak [Ryan Phillips]
 - libuv: Reap zombies on spawn [Ryan Phillips]
 - luvi: Use static runtime on windows [Rob Emanuele]
 - luvi: Add luvi_renamed.lib for windows DLL loading [Rob Emanuele]
 - luvi: Fix custom LUVI_MAIN [Ryan Liptak]

## v1.0.0

 - luvi: Add bundle.action API for using objects from the zip bundle. [Tim Caswell]
 - luvi: Remove auto coroutine.wrap, uv.start, and uv.stop. [Tim Caswell]
 - luvi: Use proper mainpath for auto-require. [Tim Caswell]
 - luvi: fix packaging, add -Wall and fix warning [Ryan Phillips]
 - luv: expose O_EXLOCK constant on platforms that have it. [Tim Caswell]
 - lua-openssl: Update upstream.


## v0.8.1

 - luv: Update to libuv v1.4.2-4-gfd3cf20 [Daniel Barney]
 - cmake: Fix zlib and openssl cmake files for Solaris [Daniel Barney]

## v0.8.0

 - luvi: Add conventions to make bootstrapping for apps easier. [Tim Caswell]
   - If deps/require.lua exists, auto-register it as luvit require system.
   - If deps/pretty-print module exists, use it to set _G.p and _G.print.
   - Run main.lua in a coroutine off the main lua "thread".
   - Auto-start uv loop after starting main.lua.
   - Auto-stop uv loop after main.lua finishes.
 - luvi: export libuv externs for binary addons to use. [Ryan Phillips]
 - luvi: Add basic packaging code using cpack. [Ryan Phillips]

## v0.7.1

 - luvi: Add ability to run from zips with folder at root [Tim Caswell]
 - luvi: Export makeBundle as an API [Tim Caswell]
 - windows: Tweak build to allow for shared libraries at runtime. [Ryan Phillips]

## v0.7.0

 - lua-openssl: Update to latest [Tim Caswell]
 - luvi: Use LUV_MAIN instead of package.lua for custom main
 - luvi: Add `publish-src`, `publish-tiny`, `publish-static`, etc targets
         which publish to github releases for tags.

## v0.6.6

 - luvi: Allow custom main by reading package.lua [Tim Caswell]
 - lua-openssl: Update for more fixes [Ryan Phillips]
 - cmake: Add support for freebsd [Ryan Phillips]

## v0.6.5

 - luv: Add getpid, getuid, getgid, setuid, setgid [Ryan Phillips]

## v0.6.4

 - lua-openssl: Update to fix more crashers [Ryan Phillips]
 - libuv: Update to v1.4.0 [Tim Caswell]
 - libuv: Fix dirent types on Windows [Tim Caswell]
 - luvi: Change LUVI_APP to use `;` instead of `:` for separators,
         this fixes Windows paths starting with `C:/`. [Tim Caswell]

## v0.6.3

 - lua-openssl: for gc x509_store crash [Ryan Phillips]
 - luvi: add version and compile options [Ryan Phillips]

## v0.6.2

 - libuv: Update to v1.3.0
 - luv: Add sync versions of dns functions, add uv.pipe_getpeername [Tim Caswell]
 - lua-openssl: Fix infinite loop [Ryan Phillips]

## v0.6.1

 - openssl: Fix cmake build [Ryan Phillips]

## v0.6.0

 - luajit: Update to v2.0.3 [Tim Caswell]
 - libuv: Update to v1.2.1 [Tim Caswell]
 - openssl: Update to 1.0.1l [Ryan Phillips]
 - luv: Expose `lua_State` and `uv_loop` for luv extensions. [Rob Emanuele]
 - luv: fix spawn invalid command. [Ryan Phillips]
 - windows: Support for Windows Services [Rob Emanuele]

Windows Service support features:

 * Complete Windows services can be written in Luvi, example:
   https://github.com/luvit/luvi/blob/master/samples/winsvc.app/main.lua.

 * The service API closely mimics the Windows API to provide easy understanding
   of writing a service in Luvi.

 * Services can be written in their own process or a shared process.

 * Each service runs its own main function.

 * Each service has its own callback for handling service control.

 * Service control functions are provided for Creating, Deleting, Starting, and
   other control operations.

 * Extended Service configuration is provided by ChangeServiceConfig2 (service
   triggers are currently unsupported).

Internally the Windows service threads feed callbacks and control operations to
Luv.  Each service thread internally calls RegisterServiceCtrlHandlerEx as that
much be done within the context of the calling service's thread and the control
operations passed to that handler are passed to the user defined Lua handler.

## v0.5.7

 - lua: Fix handle leak for invalid commands [Ryan Phillips]

## v0.5.6

 - lua-openssl: Update upstream with various fixes

## v0.5.5

 - lua-openssl: Update upstream with various fixes
 - libuv: Update to v1.0.2
 - luajit: Update to latest in v2.1 branch
 - luv: Start docs at https://github.com/luvit/luv/blob/master/docs.md [Tim Caswell]
 - luv: use boolean return for uv_loop_alive and uv_run [Tim Caswell]
 - luvi: Fix bundle logic to skip hidden files and to not crash. [Tim Caswell]

## v0.5.4

 - lua-openssl: Update upstream with various crasher fixes.
 - luv: enable passing a table of strings to uv.write [Tim Caswell]
 - luv: make the callback optional in uv.signal_start [Tim Caswell]

## v0.5.3

 - lua-openssl: Update upstream with various crasher fixes.
 - luv: Fixed return type for uv.is_active and uv.has_ref [Thorbjørn Lindeijer]
 - luv: Add more uv.fs_open mode strings [Tim Caswell]

## v0.5.2

 - Add zlib bindings [Rob Emanuele]
 - luv: Fix return value for uv.fs_mkdtemp [Tim Caswell]

## v0.5.1

 - Use lowercase for uv type strings ("TCP" is now "tcp", "TTY" is "tty")

## v0.5.0

This release contains some breaking changes and is mostly a luv update.

 - Started keeping a changelog!
 - Start signing release tags.
 - String constants changed to be more uniform.  Are now always lowercase and
   rarely abbreviated.
 - New constants table in luv and option to pass in integers instead of string
   constants in most APIs.
 - UV userdata now have unique metatables per type allowing method use.
   `timer:start(a, b)` vs `uv.timer_start(timer, a, b)`.

## v0.4.2

 - Update libuv to final v1.0.0 release.
 - Fix and cleanup tests

## v0.4.1

 - Update lua-openssl

## v0.4.0

 - Added new LUVI_APP and LUVI_TARGET behaviors.

## v0.3.0

 - Switch to miniz for zip handling
 - Add zip writer
 - Make build system faster
 - Start building binaries for Raspberry Pi

## v0.2.1

 - Update deps and fix bugs

## v0.2.0

 - Luv no longer includes handles or reqs as the first arg in callbacks.

## v0.1.0

 - First versioned and packaged version of luvi
 - Binaries for Darwin, Linux, and Windows
