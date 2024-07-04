# luvi

[![Build Status](https://github.com/luvit/luvi/actions/workflows/ci.yml/badge.svg)](https://github.com/luvit/luvi/actions/workflows/ci.yml)

A project in-between [luv][] and [luvit][].

The goal of this is to make building [luvit][] and [derivatives][] much easier.

## Workflow

Luvi has a somewhat unique, but very easy workflow for creating self-contained binaries on systems that don't have a
compiler.

```sh
# Make a folder
git init myapp
# Write the app
vim myapp/main.lua
# Run the app
luvi myapp
# Build the binary when done
luvi myapp -o mybinary
# Build the binary with compiled Lua bytecode
luvi myapp -o mybinary --compile
# Build the binary with compiled and stripped Lua bytecode
luvi myapp -o mybinary --strip
# Run the new self-contained binary
./mybinary
# Deploy / Publish / Profit!
```

## Main API

Your `main.lua` is run in either a mostly stock [lua][] or [luajit][] environment with a few extra things added. Luajit
is built with `LUAJIT_ENABLE_LUA52COMPAT` features turned on, and all luajit [extensions][] are available. Lua is built
with the `bit` library included, for parity with luajit.

### Libuv is baked in

The "uv" module contains bindings to [libuv][] as defined in the [luv][] project. Simply `require("uv")` to access it.
The "uv" module is also provided under the name "luv" for parity with luarocks, so `require("luv")` will also work.

Use this for file I/O, network I/O, timers, or various interfaces with the operating system. This lets you write fast
non-blocking network servers or frameworks. The APIs in [luv][] mirror what's in [libuv][] allowing you to add
whatever API sugar you want on top be it callbacks, coroutines, or whatever.

Just be sure to call `uv.run()` and the end of your script to start the event loop if you want to actually wait for any
events to happen.

[extensions]: http://luajit.org/extensions.html
[lua]: https://www.lua.org/
[luajit]: https://luajit.org/
[libuv]: https://github.com/joyent/libuv
[luv]: https://github.com/luvit/luv
[luvit]: https://luvit.io/
[derivatives]: http://virgoagent.com/

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

### Integration with C's main function

The raw `argc` and `argv` from C side is exposed as a **zero** indexed lua table of strings at `args`. The `0`-th
element is generally the name of the binary that was executed.

```lua
print("Your arguments were")
for i = 0, #args do
    print(i, args[i])
end
```

The "env" module provides read/write access to your local environment variables via `env.keys`, `env.get`, `env.put`,
`env.set`, and `env.unset`.

If you return an integer from `main.lua` it will be your program's exit code.

### Bundle I/O

If you're running from a unzipped folder on disk or a zipped bundle appended to the binary, the I/O to read from this
is the same. This is exposed as the `bundle` property in the "luvi" module.

```lua
local bundle = require("luvi").bundle
local files = bundle.readdir("")
```

#### bundle.stat(path)

Load metadata about a file in the bundle. This includes `type` ("file" or "directory"), `mtime` (in ms since epoch),
and `size` (in bytes).

If the file doesn't exist, it returns `nil`.

#### bundle.readdir(path)

Read a directory. Returns a list of filenames in the directory.

If the directory doesn't exist, it return `nil`.

#### bundle.readfile(path)

Read the contents of a file. Returns a string if the file exists and `nil` if it doesn't.

## Building from Source

We maintain several [binary releases of luvi](https://github.com/luvit/luvi/releases) to ease bootstrapping of lit and
luvit apps.

The following platforms are actively supported and tested by the CI system:

- Windows >= 10 (x86_64 / i386)
- Linux >= 3.10, glibc >= 2.17 OR musl >= 1.0 (x86_64 / i386 / aarch64)
  - Debian 8+
  - Ubuntu 13.10+
  - Fedora 19+
- OSX 13+ (x86_64 / aarch64)

The following platforms are supported but not actively tested by the CI system:

- Windows >= 8 (x86_64 / i386)
- OSX 11+ (x86_64 / aarch64)
- FreeBSD 12+

Platform support is primarily based on libuv's [platform support](https://github.com/libuv/libuv/blob/v1.x/SUPPORTED_PLATFORMS.md).

Architecture support is primarily based on luajit's [platform support](https://luajit.org/luajit.html).

### Build Dependencies

If you want to not wait for pre-built binaries and dive right in, building is based on CMake and is pretty simple.

- Git
- CMake
- A C Compiler (Visual Studio 15+ OR MinGW on Windows)
- Perl (required for OpenSSL)
- NASM (required for OpenSSL ASM optimizations on Windows)

First clone this repo recursively.

```sh
git clone --recursive https://github.com/luvit/luvi.git
```

> [!IMPORTANT]
> If you're on windows, for all following steps you will need to be in a [Visual Studio Command Prompt](https://learn.microsoft.com/en-us/visualstudio/ide/reference/command-prompt-powershell?view=vs-2022).
>
> You will need to replace `make` with `nmake` in the following commands.

Then enter the directory and run the makefile inside it, which will assume you have all the dependencies installed,
primarily CMake.

Prior to building luvi you must configure the version of luvi that you want to build. Currently there are two versions:

- `tiny`: only the necessities, includes only Lua, Libuv, miniz, and minimal luvi modules.
- `regular`: the normal luvit experience, includes OpenSSL, LPeg, and lrexlib.

```sh
cd luvi
make regular
make
make test
```

When that's done you should have a luvi binary in `build/luvi`.

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
                    on top of each other.
  --version         Show luvi version and compiled in options.
  --output target   Build a luvi app by zipping the bundle and inserting luvi.
  --main path       Specify a custom main bundle path (normally main.lua)
  --compile         Compile Lua code into bytecode before bundling.
  --strip           Compile Lua code and strip debug info.
  --force           Ignore errors when compiling Lua code.
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

```text
WithOpenSSL (Default: OFF)      - Enable OpenSSL Support
WithOpenSSLASM (Default: OFF)   - Enable OpenSSL Assembly Optimizations
WithSharedOpenSSL (Default: ON) - Use System OpenSSL Library
                                  Otherwise use static library

OPENSSL_ROOT_DIR                - Override the OpenSSL Root Directory
OPENSSL_INCLUDE_DIR             - Override the OpenSSL Include Directory
OPENSSL_LIBRARIES               - Override the OpenSSL Library Path
```

Example (Static OpenSSL):

```sh
cmake \
    -DWithOpenSSL=ON \
    -DWithSharedOpenSSL=OFF \
    ..
```

Example (Shared OpenSSL):

```sh
cmake \
    -DWithSharedOpenSSL=ON \
    -DWithOpenSSL=ON \
    -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl \
    -DOPENSSL_INCLUDE_DIR=/usr/local/opt/openssl/include \
    -DOPENSSL_LIBRARIES=/usr/local/opt/openssl/lib \
    ..
```
