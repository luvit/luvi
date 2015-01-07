# Luvi Changelog

High-level changes between release versions.

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
