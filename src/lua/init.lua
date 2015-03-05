--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local os = require('ffi').os
local env = require('env')
local uv = require('uv')

local getPrefix, splitPath, joinParts

local tmpBase = os == "Windows" and (env.get("TMP") or uv.cwd()) or
                                    (env.get("TMPDIR") or '/tmp')

if os == "Windows" then
  -- Windows aware path utils
  function getPrefix(path)
    return path:match("^%u:\\") or
           path:match("^/") or
           path:match("^\\+")
  end
  function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, '([^/\\]+)') do
      table.insert(parts, part)
    end
    return parts
  end
  function joinParts(prefix, parts, i, j)
    if not prefix then
      return table.concat(parts, '/', i, j)
    elseif prefix ~= '/' then
      return prefix .. table.concat(parts, '\\', i, j)
    else
      return prefix .. table.concat(parts, '/', i, j)
    end
  end
else
  -- Simple optimized versions for unix systems
  function getPrefix(path)
    return path:match("^/")
  end
  function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, '([^/]+)') do
      table.insert(parts, part)
    end
    return parts
  end
  function joinParts(prefix, parts, i, j)
    if prefix then
      return prefix .. table.concat(parts, '/', i, j)
    end
    return table.concat(parts, '/', i, j)
  end
end

local function pathJoin(...)
  local inputs = {...}
  local l = #inputs

  -- Find the last segment that is an absolute path
  -- Or if all are relative, prefix will be nil
  local i = l
  local prefix
  while true do
    prefix = getPrefix(inputs[i])
    if prefix or i <= 1 then break end
    i = i - 1
  end

  -- If there was one, remove its prefix from its segment
  if prefix then
    inputs[i] = inputs[i]:sub(#prefix)
  end

  -- Split all the paths segments into one large list
  local parts = {}
  while i <= l do
    local sub = splitPath(inputs[i])
    for j = 1, #sub do
      parts[#parts + 1] = sub[j]
    end
    i = i + 1
  end

  -- Evaluate special segments in reverse order.
  local skip = 0
  local reversed = {}
  for idx = #parts, 1, -1 do
    local part = parts[idx]
    if part == '.' then
      -- Ignore
    elseif part == '..' then
      skip = skip + 1
    elseif skip > 0 then
      skip = skip - 1
    else
      reversed[#reversed + 1] = part
    end
  end

  -- Reverse the list again to get the correct order
  parts = reversed
  for idx = 1, #parts / 2 do
    local j = #parts - idx + 1
    parts[idx], parts[j] = parts[j], parts[idx]
  end

  local path = joinParts(prefix, parts)
  return path
end

return function(args)

  local uv = require('uv')
  local luvi = require('luvi')
  local env = require('env')

  -- Given a list of bundles, merge them into a single vfs.  Lower indexed items overshawdow later items.
  local function combinedBundle(bundles)
    local bases = {}
    for i = 1, #bundles do
      bases[i] = bundles[i].base
    end
    return {
      base = table.concat(bases, " : "),
      stat = function (path)
        local err
        for i = 1, #bundles do
          local stat
          stat, err = bundles[i].stat(path)
          if stat then return stat end
        end
        return nil, err
      end,
      readdir = function (path)
        local has = {}
        local files, err
        for i = 1, #bundles do
          local list
          list, err = bundles[i].readdir(path)
          if list then
            for j = 1, #list do
              local name = list[j]
              if has[name] then
                print("Warning multiple overlapping versions of " .. name)
              else
                has[name] = true
                if files then
                  files[#files + 1] = name
                else
                  files = { name }
                end
              end
            end
          end
        end
        if files then
          return files
        else
          return nil, err
        end
      end,
      readfile = function (path)
        local err
        for i = 1, #bundles do
          local data
          data, err = bundles[i].readfile(path)
          if data then return data end
        end
        return nil, err
      end
    }
  end

  local function folderBundle(base)
    return {
      base = base,
      stat = function (path)
        path = pathJoin(base, "./" .. path)
        local raw, err = uv.fs_stat(path)
        if not raw then return nil, err end
        return {
          type = string.lower(raw.type),
          size = raw.size,
          mtime = raw.mtime,
        }
      end,
      readdir = function (path)
        path = pathJoin(base, "./" .. path)
        local req, err = uv.fs_scandir(path)
        if not req then return nil, err end

        local files = {}
        repeat
          local ent = uv.fs_scandir_next(req)
          if ent then files[#files + 1] = ent.name end
        until not ent
        return files
      end,
      readfile = function (path)
        path = pathJoin(base, "./" .. path)
        local fd, stat, data, err
        fd, err = uv.fs_open(path, "r", 0644)
        if not fd then return nil, err end
        stat, err = uv.fs_fstat(fd)
        if not stat then return nil, err end
        data, err = uv.fs_read(fd, stat.size, 0)
        if not data then return nil, err end
        uv.fs_close(fd)
        return data
      end,
    }
  end

  local function chrootBundle(bundle, prefix)
    local bundleStat = bundle.stat
    function bundle.stat(path)
      return bundleStat(prefix .. path)
    end
    local bundleReaddir = bundle.readdir
    function bundle.readdir(path)
      return bundleReaddir(prefix .. path)
    end
    local bundleReadfile = bundle.readfile
    function bundle.readfile(path)
      return bundleReadfile(prefix .. path)
    end
  end

  local function zipBundle(base, zip)
    local bundle = {
      base = base,
      stat = function (path)
        path = pathJoin("./" .. path)
        if path == "" then
          return {
            type = "directory",
            size = 0,
            mtime = 0
          }
        end
        local err
        local index = zip:locate_file(path)
        if not index then
          index, err = zip:locate_file(path .. "/")
          if not index then return nil, err end
        end
        local raw = zip:stat(index)

        return {
          type = raw.filename:sub(-1) == "/" and "directory" or "file",
          size = raw.uncomp_size,
          mtime = raw.time,
        }
      end,
      readdir = function (path)
        path = pathJoin("./" .. path)
        local index, err
        if path == "" then
          index = 0
        else
          path = path .. "/"
          index, err = zip:locate_file(path )
          if not index then return nil, err end
          if not zip:is_directory(index) then
            return nil, path .. " is not a directory"
          end
        end
        local files = {}
        for i = index + 1, zip:get_num_files() do
          local filename = zip:get_filename(i)
          if string.sub(filename, 1, #path) ~= path then break end
          filename = filename:sub(#path + 1)
          local n = string.find(filename, "/")
          if n == #filename then
            filename = string.sub(filename, 1, #filename - 1)
            n = nil
          end
          if not n then
            files[#files + 1] = filename
          end
        end
        return files
      end,
      readfile = function (path)
        path = pathJoin("./" .. path)
        local index, err = zip:locate_file(path)
        if not index then return nil, err end
        return zip:extract(index)
      end
    }

    -- Support zips with a single folder inserted at toplevel
    local entries = bundle.readdir("")
    if #entries == 1 and bundle.stat(entries[1]).type == "directory" then
      chrootBundle(bundle, entries[1] .. '/')
    end

    return bundle
  end

  local function makeBundle(app)
    local miniz = require('miniz')
    if app and (#app > 0) then
      -- Split the string by ; leaving empty strings on ends
      local parts = {}
      local n = 1
      for part in string.gmatch(app, '([^;]*)') do
        if not parts[n] then
          local path
          if part == "" then
            path = uv.exepath()
          else
            path = pathJoin(uv.cwd(), part)
          end
          local bundle
          local zip = miniz.new_reader(path)
          if zip then
            bundle = zipBundle(path, zip)
          else
            local stat = uv.fs_stat(path)
            if not stat or stat.type ~= "directory" then
              print("ERROR: " .. path .. " is not a zip file or a folder")
              return
            end
            bundle = folderBundle(path)
          end
          parts[n] = bundle
        end
        if part == "" then n = n + 1 end
      end
      if #parts == 1 then
        return parts[1]
      end
      return combinedBundle(parts)
    end
    local path = uv.exepath()
    local zip = miniz.new_reader(path)
    if zip then return zipBundle(path, zip) end
  end

  local function commonBundle(bundle)

    function bundle.action(path, action, ...)
      -- If it's a real path, run it directly.
      if uv.fs_access(path, "r") then return action(path) end
      -- Otherwise, copy to a temporary folder and run from there
      local data, err = bundle.readfile(path)
      if not data then return nil, err end
      local dir = assert(uv.fs_mkdtemp(pathJoin(tmpBase, "lib-XXXXXX")))
      path = pathJoin(dir, path:match("[^/\\]+$"))
      local fd = uv.fs_open(path, "w", 384) -- 0600
      uv.fs_write(fd, data, 0)
      uv.fs_close(fd)
      local success, ret = pcall(action, path, ...)
      uv.fs_unlink(path)
      uv.fs_rmdir(dir)
      assert(success, ret)
      return ret
    end

    luvi.bundle = bundle
    luvi.makeBundle = makeBundle

    luvi.path = {
      join = pathJoin,
      getPrefix = getPrefix,
      splitPath = splitPath,
      joinparts = joinParts,
    }

    bundle.register = function (name, path)
      if not path then path = name + ".lua" end
      package.preload[name] = function (...)
        local lua = assert(bundle.readfile(path))
        return assert(loadstring(lua, "bundle:" .. path))(...)
      end
    end

    local mainPath, main
    mainPath = env.get("LUVI_MAIN")
    if mainPath then
      main = bundle.readFile(mainPath)
    else
      local base = string.match(args[0], "[^/]*$")
      if base then
        mainPath = "main/" .. base .. ".lua"
        main = bundle.readfile(mainPath)
      end
      if not main then
        mainPath = "main.lua"
        main = bundle.readfile(mainPath)
      end
    end

    if not main then error("Missing " .. mainPath .. " in " .. bundle.base) end
    _G.args = args

    -- Auto-register the require system if present
    local mainRequire
    local stat = bundle.stat("deps/require.lua")
    if stat and stat.type == "file" then
      bundle.register('require', "deps/require.lua")
      mainRequire = require('require')("bundle:" .. mainPath)
    end

    -- Auto-setup global p and libuv version of print
    if mainRequire and bundle.stat("deps/pretty-print") or bundle.stat("deps/pretty-print.lua") then
      _G.p = mainRequire('pretty-print').prettyPrint
    end

    -- Wrap main in a coroutine and auto start-stop the uv loop.
    local returnCode
    coroutine.wrap(function ()
      local fn = assert(loadstring(main, "bundle:main.lua"))
      if mainRequire then
        setfenv(fn, setmetatable({
          require = mainRequire
        }, {
          __index=_G
        }))
      end
      returnCode = fn(unpack(args))
    end)()
    uv.run();
    return returnCode

  end

  local function generateOptionsString()
    local s = {}
    for k, v in pairs(luvi.options) do
      if type(v) == 'boolean' then
        table.insert(s, k)
      else
        table.insert(s, string.format("%s: %s", k, v))
      end
    end
    return table.concat(s, "\n")
  end

  local function buildBundle(target, bundle)
    local miniz = require('miniz')
    target = pathJoin(uv.cwd(), target)
    print("Creating new binary: " .. target)
    local fd = assert(uv.fs_open(target, "w", 511)) -- 0777
    local binSize
    do
      local source = uv.exepath()

      local reader = miniz.new_reader(source)
      if reader then
        -- If contains a zip, find where the zip starts
        binSize = reader:get_offset()
      else
        -- Otherwise just read the file size
        binSize = uv.fs_stat(source).size
      end
      local fd2 = assert(uv.fs_open(source, "r", 384)) -- 0600
      print("Copying initial " .. binSize .. " bytes from " .. source)
      uv.fs_sendfile(fd, fd2, 0, binSize)
      uv.fs_close(fd2)
    end

    local writer = miniz.new_writer()
    local function copyFolder(path)
      local files = bundle.readdir(path)
      if not files then return end
      for i = 1, #files do
        local name = files[i]
        if string.sub(name, 1, 1) ~= "." then
          local child = pathJoin(path, name)
          local stat = bundle.stat(child)
          if stat.type == "directory" then
            writer:add(child .. "/", "")
            copyFolder(child)
          elseif stat.type == "file" then
            print("    " .. child)
            writer:add(child, bundle.readfile(child), 9)
          end
        end
      end
    end
    print("Zipping " .. bundle.base)
    copyFolder("")
    print("Writing zip file")
    uv.fs_write(fd, writer:finalize(), binSize)
    uv.fs_close(fd)
    print("Done building " .. target)
    return
  end

  local bundle = makeBundle(env.get("LUVI_APP"))
  if bundle then
    local target = env.get("LUVI_TARGET")
    if not target or #target == 0 then return commonBundle(bundle) end
    return buildBundle(target, bundle)
  end
  local prefix = string.format("%s %s", args[0], luvi.version)
  local options = generateOptionsString()
  local usage = [[

Usage:

    Bare Luvi uses environment variables to configure its runtime parameters.

    LUVI_APP is a semicolon separated list of paths to folders and/or zip files to
             be used as the bundle virtual file system.  Items are searched in
             the paths from left to right.

    LUVI_MAIN is the path to a custom `main.lua`.  It's path is relative to the bundle
              root.  For example, a test runner might use `LUVI_MAIN=tests/run.lua`.

    LUVI_TARGET is set when you wish to build a new binary instead of running
                directly out of the raw folders.  Set this in addition to
                LUVI_APP and luvi will build a new binary with the vfs embedded
                inside as a single zip file at the end of the executable.

    Examples:

      # Run luvit directly from the filesystem (like a git checkout)
      LUVI_APP=luvit/app $(LUVI)

      # Run an app that layers on top of luvit
      "LUVI_APP=myapp;luvit/app" $(LUVI)

      # Build the luvit binary
      LUVI_APP=luvit/app LUVI_TARGET=./luvit $(LUVI)

      # Run the new luvit binary
      ./luvit

      # Run an app that layers on top of luvit (note trailing semicolon)
      "LUVI_APP=myapp;" ./luvit

      # Build your app
      "LUVI_APP=myapp;" LUVI_TARGET=mybinary ./luvit]]
  usage = string.gsub(usage, "%$%(LUVI%)", args[0])
  print(prefix)
  print()
  print(options)
  print(usage)
  return -1

end
