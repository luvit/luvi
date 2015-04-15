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
local luvi = require('luvi')
local miniz = require('miniz')

local getPrefix, splitPath, joinParts

local tmpBase = os == "Windows" and (env.get("TMP") or uv.cwd()) or
                                    (env.get("TMPDIR") or '/tmp')

if os == "Windows" then
  -- Windows aware path utils
  function getPrefix(path)
    return path:match("^%a:\\") or
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

-- Bundle from folder on disk
local function folderBundle(base)
  local bundle = { base = base }

  function bundle.stat(path)
    path = pathJoin(base, "./" .. path)
    local raw, err = uv.fs_stat(path)
    if not raw then return nil, err end
    return {
      type = string.lower(raw.type),
      size = raw.size,
      mtime = raw.mtime,
    }
  end

  function bundle.readdir(path)
    path = pathJoin(base, "./" .. path)
    local req, err = uv.fs_scandir(path)
    if not req then
      return nil, err
    end

    local files = {}
    repeat
      local ent = uv.fs_scandir_next(req)
      if ent then
        files[#files + 1] = ent.name
      end
    until not ent
    return files
  end

  function bundle.readfile(path)
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
  end

  return bundle
end

-- Insert a prefix into all bundle calls
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

-- Use a zip file as a bundle
local function zipBundle(base, zip)
  local bundle = { base = base }

  function bundle.stat(path)
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
  end

  function bundle.readdir(path)
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
  end

  function bundle.readfile(path)
    path = pathJoin("./" .. path)
    local index, err = zip:locate_file(path)
    if not index then return nil, err end
    return zip:extract(index)
  end

  -- Support zips with a single folder inserted at toplevel
  local entries = bundle.readdir("")
  if #entries == 1 and bundle.stat(entries[1]).type == "directory" then
    chrootBundle(bundle, entries[1] .. '/')
  end

  return bundle
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

-- Given a list of bundles, merge them into a single vfs.  Lower indexed items overshawdow later items.
local function combinedBundle(bundles)
  local bases = {}
  for i = 1, #bundles do
    bases[i] = bundles[i].base
  end
  local bundle = { base = table.concat(bases, ";") }

  function bundle.stat(path)
    local err
    for i = 1, #bundles do
      local stat
      stat, err = bundles[i].stat(path)
      if stat then return stat end
    end
    return nil, err
  end

  function bundle.readdir(path)
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
  end

  function bundle.readfile(path)
    local err
    for i = 1, #bundles do
      local data
      data, err = bundles[i].readfile(path)
      if data then return data end
    end
    return nil, err
  end

  return bundle
end

local function makeBundle(parts)
  for n = 1, #parts do
    local path = pathJoin(uv.cwd(), parts[n])
    local bundle
    local zip = miniz.new_reader(path)
    if zip then
      bundle = zipBundle(path, zip)
    else
      local stat = uv.fs_stat(path)
      if not stat or stat.type ~= "directory" then
        error("ERROR: " .. path .. " is not a zip file or a folder")
      end
      bundle = folderBundle(path)
    end
    parts[n] = bundle
  end
  if #parts == 1 then
    return parts[1]
  end
  return combinedBundle(parts)
end

local function commonBundle(bundle, args)

  luvi.makeBundle = makeBundle
  luvi.bundle = bundle

  luvi.path = {
    join = pathJoin,
    getPrefix = getPrefix,
    splitPath = splitPath,
    joinparts = joinParts,
  }

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

  function bundle.register(name, path)
    if not path then path = name + ".lua" end
    package.preload[name] = function (...)
      local lua = assert(bundle.readfile(path))
      return assert(loadstring(lua, "bundle:" .. path))(...)
    end
  end

  local mainPath = "main.lua"
  local main = bundle.readfile(mainPath)

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

  local fn = assert(loadstring(main, "bundle:" .. mainPath))
  if mainRequire then
    setfenv(fn, setmetatable({
      require = mainRequire
    }, {
      __index=_G
    }))
  end
  return fn(unpack(args))

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

local commands = {
  ["-o"] = "output",
  ["--output"] = "output",
  ["-v"] = "version",
  ["--version"] = "version",
  ["-h"] = "help",
  ["--help"] = "help",
}

local function version(args)
  print(string.format("%s %s", args[0], luvi.version))
  print(generateOptionsString())
end

local function help(args)

  local usage = [[
Usage: $(LUVI) bundle+ [options] [-- extra args]

  bundle            Path to directory or zip file containing bundle source.
                    `bundle` can be specified multiple times to layer bundles
                    on top of eachother.
  --version         Show luvi version and compiled in options.
  --output target   Build a luvi app by zipping the bundle and inserting luvi.
  --help            Show this help file.
  --                All args after this go to the luvi app itself.

Examples:

  # Run an app from disk, but pass in arguments
  $(LUVI) path/to/app -- app args

  # Run from a app zip
  $(LUVI) path/to/app.zip

  # Run an app that layers on top of luvit
  $(LUVI) path/to/app path/to/luvit

  # Bundle an app with luvi to create standalone
  $(LUVI) path/to/app -o target
  ./target some args
]]
  print((string.gsub(usage, "%$%(LUVI%)", args[0])))
end

return function(args)

  -- First check for a bundled zip file appended to the executible
  local path = uv.exepath()
  local zip = miniz.new_reader(path)
  if zip then
    return commonBundle(zipBundle(path, zip), args)
  end

  -- Parse the arguments
  local bundles = { }
  local options = {}
  local appArgs = { [0] = args[0] }

  local key
  for i = 1, #args do
    local arg = args[i]
    if arg == "--" then
      for j = i + 1, #args do
        appArgs[#appArgs + 1] = args[j]
      end
      break
    elseif key then
      options[key] = arg
      key = nil
    else
      local command = commands[arg]
      if options[command] then
        error("Duplicate flags: " .. command)
      end
      if command == "output" then
        key = "output"
      elseif command then
        options[command] = true
      else
        if arg:sub(1, 1) == "-" then
          error("Unknown flag: " .. arg)
        end
        bundles[#bundles + 1] = arg
      end
    end
  end

  if key then
    error("Missing value for option: " .. key)
  end

  -- Show help and version by default
  if #bundles == 0 and not options.version and not options.help then
    options.version = true
    options.help = true
  end

  if options.version then
    version(args)
  end
  if options.help then
    help(args)
  end

  -- Don't run app when printing version or help
  if options.version or options.help then return -1 end

  local bundle = assert(makeBundle(bundles))

  -- Build the app if output is given
  if options.output then
    return buildBundle(options.output, bundle)
  end

  -- Run the luvi app with the extra args
  return commonBundle(bundle, appArgs)

end
