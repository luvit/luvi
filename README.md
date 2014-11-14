luvi
====

[![Linux Build Status](https://travis-ci.org/luvit/luvi.svg?branch=master)](https://travis-ci.org/luvit/luvi)

[![Windows Build Status](https://ci.appveyor.com/api/projects/status/github/luvit/luvi?branch=master&svg=true)](https://ci.appveyor.com/project/creationix/luvi)

A project in-between [luv][] and [luvit][].

The goal of this is to make building [luvit][] and [derivatives][] much easier.

## Usage

 1. Create your lua program.  This consists of a folder with a `main.lua` in
    it's root.
 2. From somewhere inside your app, type `luvi` to run the current app.
 3. When you are pleased with the result, zip your folder making sure `main.lua`
    is in the root of the new zip file.  Then concatenate the `luvi` binary with
    your zip to form a new binary.  Mark it as executable and distribute.

## Main API

Your `main.lua` is run in a mostly stock [luajit][] environment with a few extra
things added.  This means you can use the luajit [extensions][] including
`DLUAJIT_ENABLE_LUA52COMPAT` features which we turn on.

### LibUV is baked in.

The "uv" module containt bindings to [libuv][] as defined in the [luv][]
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

The "env" table under "luvi" provides read/write access to your local environment variables
via `env.keys`, `env.get`, `env.put`, `env.set`, and `env.unset`.

```lua
local env = require('luvi').env

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

If you want to not wait for pre-built binaries and dive right in, building on
Linux or OSX is pretty simple.

First clone this repo recursively.

```shell
git clone --recursive git@github.com:luvit/luvi.git
```

Then run the makefile inside it. (Note this assumes you have cmake in your path.)

```sh
cd luvi
make
```

When that's done you should have a shiny little binary `in build/luvi`.

```sh
$ ls -lh build/luvi
-rwxr-xr-x 1 tim tim 878K Oct 20 17:55 build/luvi
```

If you try to run it outside an app, it will fail:

```sh
$ ./build/luvi
Not a luvi app tree.
```

You can run the sample repl app by doing:

```sh
LUVI_DIR=samples/repl.app build/luvi
```

When you're done creating an app you need to zip your app and concatenate it
with luvi.  Make sure that `main.lua` is at the root of your zip file.  For
example on osx or linux:

```sh
cd my-app
zip -r -9 ../my-app.zip .
cd ..
unzip -l my-app.zip # verify the paths in the zip file
cat path/to/luvi my-app.zip > my-app.bin
chmod +x my-app.bin
./my-app.bin
```

Building on Windows is also pretty simple.  Make sure to install visual studio
desktop or some C compiler and enter the appropriate command shell.

Run the `msvcbuild.bat` script to build luvi using cmake and MSVC.  The final
binary will copied to `luvi.exe` in the root for convenience.

## CMake Flags

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
