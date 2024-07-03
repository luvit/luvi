local luvi = require('luvi')
local getPrefix, splitPath, joinParts

local isWindows
if pcall(require, 'jit') then
  isWindows = require('jit').os == "Windows"
else
  isWindows = not not (package.config:sub(1, 1) == "\\" or package.path:find("\\", 1, true) or package.cpath:find("\\", 1, true))
end

if isWindows then
  -- Windows aware path utilities
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
  -- Simple optimized versions for UNIX systems
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
    if part ~= '.' then
      if part == '..' then
        skip = skip + 1
      elseif skip > 0 then
        skip = skip - 1
      else
        reversed[#reversed + 1] = part
      end
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

-- Legacy path exports
luvi.path = {
  join = pathJoin,
  getPrefix = getPrefix,
  splitPath = splitPath,
  joinparts = joinParts,
}

return {
  isWindows = isWindows,
  getPrefix = getPrefix,
  splitPath = splitPath,
  joinParts = joinParts,
  pathJoin = pathJoin,
}
