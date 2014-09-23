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
  function joinParts(prefix, parts)
    if prefix == '/' then
      return prefix .. table.concat(parts, '/')
    elseif prefix then
      return prefix .. table.concat(parts, '\\')
    end
    return table.concat(parts, '\\')
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
  function joinParts(prefix, parts)
    if prefix then
      return prefix .. table.concat(parts, '/')
    end
    return table.concat(parts, '/')
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

return function(base, ...)

  local uv = require('uv')
  local luvi = require('luvi')
  local bundle

  if base then
    base = pathJoin(uv.cwd(), base)
    bundle = {
      stat = function (path)
        local raw, err = uv.fs_stat(pathJoin(base, path))
        if not raw then return nil, err end
        return {
          type = raw.is_directory and "directory" or
                 raw.is_file and "file" or
                 raw.is_symbolic_link and "symbolic_link" or
                 raw.is_socket and "socket" or
                 raw.is_block_device and "block_device" or
                 raw.is_character_device and "is_character_device" or
                 "unknown",
          size = raw.size,
          mtime = raw.mtime,
        }
      end,
      readdir = function (path)
        return uv.fs_readdir(pathJoin(base, path))
      end,
      readfile = function (path)
        path = pathJoin(base, path)
        local fd, err = uv.fs_open(path, "r", tonumber("644", 8))
        if not fd then return nil, err end
        local stat, err = uv.fs_fstat(fd)
        if not stat then return nil, err end
        local data, err = uv.fs_read(fd, stat.size, nil)
        if not data then return nil, err end
        uv.fs_close(fd)
        return data
      end,
    }
  else

    local fd = uv.fs_open(uv.execpath(), 'r', tonumber('644', 8))
    local zip = require('zipreader')(fd, {
      fstat=uv.fs_fstat,
      read=uv.fs_read
    })
    if not zip then
      print("Usage: " .. args[0] .. " path/to/app-folder")
      return 1
    end

    bundle = {
      stat = function (path)
        if path == "" then
          return {
            type = "directory",
            size = 0,
            mtime = 0
          }
        end
        local raw, err = zip.stat(path)
        if not raw then return nil, err end
        return {
          type = raw.file_name:sub(-1) == "/" and "directory" or "file",
          size = raw.uncompressed_size,
          mtime = 0, -- TODO: parse last_mod_file_date and last_mod_file_time
        }
      end,
      readdir = function (path)
        local entries, err = zip.readdir(path)
        if not entries then return nil, err end
        local keys={}
        local n = 0
        for k,v in pairs(entries) do
          n = n + 1
          keys[n] = k
        end
        return keys
      end,
      readfile = zip.readfile,
    }
  end

  luvi.bundle = bundle

  bundle.register = function (name, path)
    if not path then path = name + ".lua" end
    local lua = assert(bundle.readfile(path))
    package.preload[name] = assert(loadstring(lua, path))
  end

  bundle.pathJoin = pathJoin

  local main = bundle.readfile("main.lua")
  if not main then error("Missing main.lua in bundle") end
  return loadstring(main, "bundle:main.lua")(base, ...)

end
