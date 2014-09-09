luvi
====

A project in-between [luv][] and [luvit][].

The goal of this is to make building [luvit][] and [derivatives][] much easier.

This project is still in progress, but once done, it will be used as follows:

## Usage

 1. Create your lua program.  This consists of a folder with a `main.lua` in
    it's root.
 2. Test your unzipped program with bare `luvi` by setting the`LUVI_IN`
    environment variable to point to your folder.
 3. When wou are pleased with the result, zip your folder making sure `main.lua`
    is in the root of the new zip file.  Then concatenate the `luvi` binary with
    your zip to form a new binary.  Mark it as executable and distribute.

## Main API

Your `main.lua` is run in a mostly stock [luajit][] environment with a few extra
things added.  This means you can use the luajit [extensions][] including
`DLUAJIT_ENABLE_LUA52COMPAT` features which we turn on.

### LibUV is baked in.

The global `uv` table is bindings to [libuv][] as defined in the [luv][] project.

Use this for file I/O, network I/O, timers, or various interfaces with the
operating system.  This lets you write fast non-blocking network servers or
frameworks.  The APIs in [luv][] mirror what's in [libuv][] allowing you to add
whatever API sugar you want on top be it callbacks, coroutines, or whatever.

Just be sure to call `uv.run('default')` and the end of your script to start the
event loop if you want to actually wait for any events to happen.

### Integration with C's main function.

The raw `argc` and `argv` from C side is exposed as a **zero** indexed lua table
of strings at `args`.

Also `...` in main is the program args skipping the first (usually path to your
binary or `luvi`).  So it's the arguments to your program.

If you return an integer from this file, it will be your program's exit code.

### Bundle I/O

If you're running from a unzipped folder on disk or a zipped bundle appended to
the directory, the I/O to read from this is the same.  This is exposed as the
global `bundle` table.

### bundle.stat(path)

Load metadata about a file in the bundle.  This includes `type` ("file" or
"tree"), `mtime` (in ms since epoch), and `size` (in bytes).

If the file doesn't exist, it returns `nil`.

### bundle.readdir(path)

Read a directory.  Returns a table indexed by filename with stat entries for
values.

If the directory doesn't exist, it return `nil`.

### bundle.readfile(path)

Read the contents of a file.  Returns a string if the file exists and `nil` if
it doesn't.

[extensions]: http://luajit.org/extensions.html
[luajit]: http://luajit.org/
[libuv]: https://github.com/joyent/libuv
[luv]: https://github.com/luvit/luv
[luvit]: https://luvit.io/
[derivatives]: http://virgoagent.com/
