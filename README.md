luvi
====

[![Linux Build Status](https://travis-ci.org/luvit/luvi.svg?branch=master)](https://travis-ci.org/luvit/luvi)

[![Windows Build Status](https://ci.appveyor.com/api/projects/status/github/luvit/luvi?branch=master&svg=true)](https://ci.appveyor.com/project/creationix/luvi)

A project in-between [luv][] and [luvit][].

The goal of this is to make building [luvit][] and [derivatives][] much easier.

## Workflow

Luvi has a somewhat unique, but very easy workflow for creating self-contained
binaries on systems that don't have a compiler.

```sh
# Make a folder
git init myapp
# Write the app
vim myapp/main.lua
# Run the app
LUVI_APP=myapp luvi
# Build the binary when done
LUVI_APP=myapp LUVI_TARGET=mybinary luvi
# Run the new self-contained binary
./mybinary
# Deploy / Publish / Profit!
```

## Main API

Your `main.lua` is run in a mostly stock [luajit][] environment with a few extra
things added.  This means you can use the luajit [extensions][] including
`DLUAJIT_ENABLE_LUA52COMPAT` features which we turn on.

### LibUV is baked in.

The "uv" module contains bindings to [libuv][] as defined in the [luv][]
project.  Simply `require("uv")` to access it.

Use this for file I/O, network I/O, timers, or various interfaces with the
operating system.  This lets you write fast non-blocking network servers or
frameworks.  The APIs in [luv][] mirror what's in [libuv][] allowing you to add
whatever API sugar you want on top be it callbacks, coroutines, or whatever.

Just be sure to call `uv.run()` and the end of your script to start the
event loop if you want to actually wait for any events to happen.

```lua
local uv = require('uv')

local function setTimeout(timeout, callback)
  local timer = uv.new_timer()
  local function ontimeout()
    p("ontimeout", self)
    uv.timer_stop(timer)
    uv.close(timer)
    callback(self)
  end
  uv.timer_start(timer, timeout, 0, ontimeout)
  return timer
end

setTimeout(1000, function ()
  print("This happens later")
end)

print("This happens first")

-- This blocks till the timer is done
uv.run()
```

### Integration with C's main function.

The raw `argc` and `argv` from C side is exposed as a **zero** indexed lua table
of strings at `args`.

```lua
print("Your arguments were", args)
```

The "env" module provides read/write access to your local environment variables
via `env.keys`, `env.get`, `env.put`, `env.set`, and `env.unset`.

```lua
local env = require('env')

-- Convert the module to a mutable magic table.
local environment = setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys()
    local index = 0
    return function (...)
      index = index + 1
      local name = keys[index]
      if name then
        return name, table[name]
      end
    end
  end,
  __index = function (table, name)
    return env.get(name)
  end,
  __newindex = function (table, name, value)
    if value then
      env.set(name, value, 1)
    else
      env.unset(name)
    end
  end
}))
```

If you return an integer from `main.lua` it will be your program's exit code.

### Bundle I/O

If you're running from a unzipped folder on disk or a zipped bundle appended to
the binary, the I/O to read from this is the same.  This is exposed as the
 `bundle` property in the "luvi" module.

 ```lua
 local bundle = require("luvi").bundle
 local files = bundle.readdir("")
 ```

#### bundle.stat(path)

Load metadata about a file in the bundle.  This includes `type` ("file" or
"tree"), `mtime` (in ms since epoch), and `size` (in bytes).

If the file doesn't exist, it returns `nil`.

#### bundle.readdir(path)

Read a directory.  Returns a list of filenames in the directory.

If the directory doesn't exist, it return `nil`.

#### bundle.readfile(path)

Read the contents of a file.  Returns a string if the file exists and `nil` if
it doesn't.

### Utils

There is also a "utils" module that has some useful debugging stuff like a colorized
pretty printer.

```lua
local uv = require('uv')
local dump = require('utils').dump
-- Create a global p() function that pretty prints any values
-- to stdout using libuv's APIs
_G.p = function (...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = dump(arguments[i])
  end

  local toWrite = table.concat(arguments, "\t") .. "\n"
  uv.write(stdout, toWrite);
end
```

[extensions]: http://luajit.org/extensions.html
[luajit]: http://luajit.org/
[libuv]: https://github.com/joyent/libuv
[luv]: https://github.com/luvit/luv
[luvit]: https://luvit.io/
[derivatives]: http://virgoagent.com/

## Building from Source

[Prebuilt binaries][] are kept for most platforms including Windows, OSX, Linux
x64 and Linux for Raspberry Pi.

If you want to not wait for pre-built binaries and dive right in, building is
based on CMake and is pretty simple.

First clone this repo recursively.

```shell
git clone --recursive git@github.com:luvit/luvi.git
```

Then run the makefile inside it. (Note this assumes you have cmake in your path.)
If you're on windows, there is a `make.bat` file that works mostly like the unix
`Makefile`.


```sh
cd luvi
make
```

When that's done you should have a shiny little binary `in build/luvi`.

```sh
$ ls -lh build/luvi
-rwxr-xr-x 1 tim tim 948K Nov 20 16:39 build/luvi
```

## Usage

Run it to see usage information:

```sh
$ ./build/luvi

Luvi Usage Instructions:

    Bare Luvi uses environment variables to configure its runtime parameters.

    LUVI_APP is a colon separated list of paths to folders and/or zip files to
             be used as the bundle virtual file system.  Items are searched in
             the paths from left to right.

    LUVI_TARGET is set when you wish to build a new binary instead of running
                directly out of the raw folders.  Set this in addition to
                LUVI_APP and luvi will build a new binary with the vfs embedded
                inside as a single zip file at the end of the executable.

    Examples:

      # Run luvit directly from the filesystem (like a git checkout)
      LUVI_APP=luvit/app ./build/luvi

      # Run an app that layers on top of luvit
      LUVI_APP=myapp:luvit/app ./build/luvi

      # Build the luvit binary
      LUVI_APP=luvit/app LUVI_TARGET=./luvit ./build/luvi

      # Run the new luvit binary
      ./luvit

      # Run an app that layers on top of luvit (note trailing colon)
      LUVI_APP=myapp: ./luvit

      # Build your app
      LUVI_APP=myapp: LUVI_TARGET=mybinary ./luvit
```

You can run the sample repl app by doing:

```sh
LUVI_APP=samples/repl.app build/luvi
```

Ot the test suite with:

```sh
LUVI_APP=samples/test.app build/luvi
```

## Multiple Mains

Luvi also has a feature where you can reuse the same binary bundle for
multiple commands.  This is done by reading the value of `argv[0]` and looking
for a main in `"main/" .. basename(args[0]) .. ".lua"`. before looking in
`main.lua`.

To use this you will typically create multiple mains in your bundle, one for
each command you want to support.  Then when installing your app/utility,
create a symlink to the main binary in the user's `$PATH` but named after each
command.

Here is an example that has two entry points, `add` and `subtract`

```sh
mkdir main
vi main/add.lua
vi main/subtract.lua
```

Then create symlinks somewhere points to luvi (or an old version of your
binary)

```sh
ln -s luvi add
ln -s luvi subtract
```

Then when you run theses symlinks, luvi will use the custom mains.

All the previous rules about LUVI_APP and bundled zips in the binary still
apply here.

## CMake Flags

You can use the predefined makefile targets if you want or use cmake directly
for more control.

```
WithOpenSSL (Default: OFF)      - Enable OpenSSL Support
WithSharedOpenSSL (Default: ON) - Use System OpenSSL Library
                                  Otherwise use static library

OPENSSL_ROOT_DIR                - Override the OpenSSL Root Directory
OPENSSL_INCLUDE_DIR             - Override the OpenSSL Include Directory
OPENSSL_LIBRARIES               - Override the OpenSSL Library Path
```

Example (Static OpenSSL):

```
cmake \
  -DWithOpenSSL=ON \
  -DWithSharedOpenSSL=OFF \
  ..
```

Example (Shared OpenSSL):
```
cmake \
  -DWithSharedOpenSSL=ON \
  -DWithOpenSSL=ON \
  -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl \
  -DOPENSSL_INCLUDE_DIR=/usr/local/opt/openssl/include \
  -DOPENSSL_LIBRARIES=/usr/local/opt/openssl/lib \
  ..
```


[Prebuilt binaries]: https://github.com/luvit/luvi-binaries
