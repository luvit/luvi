luvi
====

[![Linux Build Status](https://travis-ci.org/luvit/luvi.svg?branch=master)](https://travis-ci.org/luvit/luvi)
[![Windows Build status](https://ci.appveyor.com/api/projects/status/h643wg5hkwsnu0wd/branch/master?svg=true)](https://ci.appveyor.com/project/racker-buildbot/luvi/branch/master)
[![Code Quality: Cpp](https://img.shields.io/lgtm/grade/cpp/g/luvit/luvi.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/luvit/luvi/context:cpp)
[![Total Alerts](https://img.shields.io/lgtm/alerts/g/luvit/luvi.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/luvit/luvi/alerts)

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
luvi myapp
# Build the binary when done
luvi myapp -o mybinary
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
    print("ontimeout", self)
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
"directory"), `mtime` (in ms since epoch), and `size` (in bytes).

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

We maintain several [binary releases of
luvi](https://github.com/luvit/luvi/releases) to ease bootstrapping of lit and
luvit apps.

The following platforms are supported:

 - Windows (amd64)
 - FreeBSD 10.1 (amd64)
 - Raspberry PI Raspbian (armv6)
 - Raspberry PI 2 Raspbian (armv7)
 - Ubuntu 14.04 (x86_64)
 - OSX Yosemite (x86_64)

If you want to not wait for pre-built binaries and dive right in, building is
based on CMake and is pretty simple.

First clone this repo recursively.

```shell
git clone --recursive https://github.com/luvit/luvi.git
```

Then run the makefile inside it. (Note this assumes you have cmake in your path.)
If you're on windows, there is a `make.bat` file that works mostly like the unix
`Makefile`.

Prior to building the `luvi` binary you must configure the version of `luvi`
that you want to build. Currently there are two versions: `regular` and `tiny`.


```sh
cd luvi
make regular
make
make test
```

When that's done you should have a shiny little binary `in build/luvi`.

```sh
$ ls -lh build/luvi
-rwxr-xr-x 1 tim tim 948K Nov 20 16:39 build/luvi
```

## Usage

Run it to see usage information:

```sh
$ luvi -h

Usage: luvi bundle+ [options] [-- extra args]

  bundle            Path to directory or zip file containing bundle source.
                    `bundle` can be specified multiple times to layer bundles
                    on top of eachother.
  --version         Show luvi version and compiled in options.
  --output target   Build a luvi app by zipping the bundle and inserting luvi.
  --main path       Specify a custom main bundle path (normally main.lua)
  --help            Show this help file.
  --                All args after this go to the luvi app itself.

Examples:

  # Run an app from disk, but pass in arguments
  luvi path/to/app -- app args

  # Run from a app zip
  luvi path/to/app.zip

  # Run an app that layers on top of luvit
  luvi path/to/app path/to/luvit

  # Bundle an app with luvi to create standalone
  luvi path/to/app -o target
  ./target some args

  # Run unit tests for a luvi app using custom main
  luvi path/to/app -m tests/run.lua
```

You can run the sample repl app by doing:

```sh
build/luvi samples/repl.app
```

Ot the test suite with:

```sh
build/luvi samples/test.app
```

## CMake Flags

You can use the predefined makefile targets if you want or use cmake directly
for more control.

```
WithOpenSSL (Default: OFF)      - Enable OpenSSL Support
WithOpenSSLASM (Default: OFF)   - Enable OpenSSL Assembly Optimizations
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

## Holy Build

Executables across Linux distributions are not largely portable for various
differences. We can leverage the
[holy-build-box](https://github.com/phusion/holy-build-box) to create a
portable executable for i686 and x86_64 environments.

Note: If you are attempting this on OSX, please install GNU tar from homebrew:

```
brew install gnu-tar
```

To get started:

1. Create a docker machine:

```
docker-machine create --driver vmwarefusion --vmwarefusion-cpu-count 3 holy-build-box
eval $(docker-machine env holy-build-box)
```

2. Start the build

```
make linux-build
```

3. Results should be the current working directory.

[Prebuilt binaries]: https://github.com/luvit/luvi/releases
