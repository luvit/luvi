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

local getPrefix, splitPath, joinParts

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

  -- If there was one, remove it's prefix from it's segment
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
  for i = #parts, 1, -1 do
    local part = parts[i]
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
  for i = 1, #parts / 2 do
    local j = #parts - i + 1
    parts[i], parts[j] = parts[j], parts[i]
  end

  local path = joinParts(prefix, parts)
  return path
end

return function(args)

  local uv = require('uv')
  local luvi = require('luvi')
  local env = require('env')

  local function commonBundle(bundle)
    luvi.bundle = bundle

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

    local main = bundle.readfile("main.lua")
    if not main then error("Missing main.lua in bundle") end
    _G.args = args
    return loadstring(main, "bundle:main.lua")(unpack(args))
  end

  local function folderBundle(base)
    return commonBundle({
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
    })
  end

  local function zipBundle(zip)

    return commonBundle({
      stat = function (path)
        path = pathJoin("./" .. path)
        if path == "" then
          return {
            type = "directory",
            size = 0,
            mtime = 0
          }
        end
        local index, err = zip:locate_file(path)
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
    })
  end

  -- If the user specified a zip file, load that
  local path = env.get("LUVI_ZIP")
  if path and #path > 0 then
    path = pathJoin(uv.cwd(), path)
    local zip = require('miniz').new_reader(path)
    -- And error out if it's not a valid zip
    if not zip then error(path .. " is not a zip file") end
    return zipBundle(zip)
  end

  -- Same for specefied directory root
  path = env.get("LUVI_DIR")
  if path and #path > 0 then
    path = pathJoin(uv.cwd(), path)
    if not uv.fs_stat(pathJoin(path, "main.lua")) then
      error(path .. " is missing main.lua at it's root")
    end
    return folderBundle(path)
  end

  -- Try to auto-detect if the exe itself contains a zip
  local zip = require('miniz').new_reader(uv.exepath())
  if zip then
    return zipBundle(zip)
  end

  -- If not search the filesystem for the folder
  -- Start at cwd and go up to the root looking for main.lua
  local dir = uv.cwd()
  local prefix = getPrefix(dir)
  local parts = splitPath(dir:sub(#prefix))
  local last = #parts
  repeat
    dir = joinParts(prefix, parts, 1, last)
    if uv.fs_stat(pathJoin(dir, "main.lua")) then
      return folderBundle(dir)
    end
    last = last - 1
  until last < 0

  print("Not a luvi app tree.")
  return 1

end
