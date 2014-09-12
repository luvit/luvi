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

return function(...)

  local uv = require('uv')
  local luvi = require('luvi')
  local env = luvi.env
  local bundle

  -- Given a path like /foo/bar and foo//bar/ return foo/bar.bar
  -- This removes leading and trailing slashes as well as multiple internal slashes.
  local function normalizePath(path)
    local parts = {}
    for part in string.gmatch(path, '([^/]+)') do
      table.insert(parts, part)
    end
    local skip = 0
    local reversed = {}
    for i = #parts, 1, -1 do
      local part = parts[i]
      if part == '.' then
        -- continue
      elseif part == '..' then
        skip = skip + 1
      elseif skip > 0 then
        skip = skip - 1
      else
        table.insert(reversed, part)
      end
    end
    parts = reversed
    for i = 1, #parts / 2 do
      local j = #parts - i + 1
      parts[i], parts[j] = parts[j], parts[i]
    end
    return table.concat(parts, '/')
  end

  local base = env.get("LUVI_IN")
  if base then
    base = base .. "/"
    bundle = {
      stat = function (path)
        local raw, err = uv.fs_stat(normalizePath(base .. path))
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
        return uv.fs_readdir(normalizePath(base .. path))
      end,
      readfile = function (path)
        local fd, err = uv.fs_open(normalizePath(base .. path), "r", tonumber("644", 8))
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
      print("Missing bundle.  Either set LUVI_IN environment variable to path to folder or append zip to this binary.")
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

  local main = bundle.readfile("main.lua")
  if not main then error("Missing main.lua in bundle") end
  return loadstring(main, "bundle:main.lua")(...)

end
