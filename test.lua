local ffi = require('ffi')

ffi.cdef[[
  struct zip_LFH {
    uint32_t signature;
    uint16_t version_needed;
    uint16_t flags;
    uint16_t compression_method;
    uint16_t last_mod_file_time;
    uint16_t last_mod_file_date;
    uint32_t crc_32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t file_name_length;
    uint16_t extra_field_length;
  } __attribute ((packed));

  struct zip_CDFH {
    uint32_t signature;
    uint16_t version;
    uint16_t version_needed;
    uint16_t flags;
    uint16_t compression_method;
    uint16_t last_mod_file_time;
    uint16_t last_mod_file_date;
    uint32_t crc_32;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint16_t file_name_length;
    uint16_t extra_field_length;
    uint16_t file_comment_length;
    uint16_t disk_number;
    uint16_t internal_file_attributes;
    uint32_t external_file_attributes;
    uint32_t local_file_header_offset;
  } __attribute__ ((packed));

  struct zip_EoCD {
    uint32_t signature;
    uint16_t disk_number;
    uint16_t central_dir_disk_number;
    uint16_t central_dir_disk_records;
    uint16_t central_dir_total_records;
    uint32_t central_dir_size;
    uint32_t central_dir_offset;
    uint16_t file_comment_length;
  } __attribute__ ((packed));
]]
-- Local File Header
local LFH = ffi.typeof("struct zip_LFH")
-- Central Directory File Header
local CDFH = ffi.typeof("struct zip_CDFH")
-- End of Central Directory
local EoCD = ffi.typeof("struct zip_EoCD")

-- Given a path like /foo/bar and foo//bar/ return foo/bar.bar
-- This removes leading and trailing slashes as well as multiple internal slashes.
local function normalizePath(path)
  local parts = {}
  for part in string.gmatch(path, "([^/]+)") do
    table.insert(parts, part)
  end
  local skip = 0
  local reversed = {}
  for i = #parts, 1, -1 do
    local part = parts[i]
    if part == "." then
      -- continue
    elseif part == ".." then
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
  return table.concat(parts, "/")
end

-- Please provide with I/O functions.
-- fsFstat(fd) takes a fd and returns a table with a .size property for file length
-- fs.read(fd, length, offset) reads from a file at offset and for a set number of bytes
--  return a string of all data
local function setup(fd, fs)

  local cd = {}

  -- Scan from the end of a file to find the start position of
  -- the EoCD (end of central directory) entry.
  local function findEoCD()
    local stat = fs.fstat(fd)

    -- Theoretically, the comment at the end can be 0x10000 bytes long
    -- though there is no sense reading more than that.
    local maxSize = 0x10000 + 22
    local start = stat.size - maxSize
    if start < 1 then
      maxSize = stat.size
      start = 1
    end
    local tail = fs.read(fd, maxSize, start)
    local position = #tail

    -- Scan backwards looking for the EoCD signature 0x06054b50
    while position > 0 do
      if string.byte(tail, position) == 0x06 and
         string.byte(tail, position - 1) == 0x05 and
         string.byte(tail, position - 2) == 0x4b and
         string.byte(tail, position - 3) == 0x50 then
        return start + position - 4
      end
      position = position - 1
    end
  end

  -- Once you know the EoCD position, you can read and parse it.
  local function readEoCD(position)
    local eocd = EoCD()
    local size = ffi.sizeof(eocd)
    local data = fs.read(fd, size, position)

    ffi.copy(eocd, data, size)

    if eocd.signature ~= 0x06054b50 then
      error "Invalid EoCD position"
    end
    local comment = fs.read(fd, eocd.file_comment_length, position + size)

    return {
      disk_number = eocd.disk_number,
      central_dir_disk_number = eocd.central_dir_disk_number,
      central_dir_disk_records = eocd.central_dir_disk_records,
      central_dir_total_records = eocd.central_dir_total_records,
      central_dir_size = eocd.central_dir_size,
      central_dir_offset = eocd.central_dir_offset,
      file_comment = comment,
    }
  end

  local function readCDFH(position, start)
    local cdfh = CDFH()
    local size = ffi.sizeof(cdfh)
    local data = fs.read(fd, size, position)

    ffi.copy(cdfh, data, size)
    if cdfh.signature ~= 0x02014b50 then
      error "Invalid CDFH position"
    end
    local n, m, k = cdfh.file_name_length, cdfh.extra_field_length, cdfh.file_comment_length
    local more = fs.read(fd, n + m + k, position + size)

    return {
      version = cdfh.version,
      version_needed = cdfh.version_needed,
      flags = cdfh.flags,
      compression_method = cdfh.compression_method,
      last_mod_file_time = cdfh.last_mod_file_time,
      last_mod_file_date = cdfh.last_mod_file_date,
      crc_32 = cdfh.crc_32,
      compressed_size = cdfh.compressed_size,
      uncompressed_size = cdfh.uncompressed_size,
      file_name = string.sub(more, 1, n),
      -- extra_field = string.sub(more, n + 1, n + m),
      comment = string.sub(more, n + m + 1),
      disk_number = cdfh.disk_number,
      internal_file_attributes = cdfh.internal_file_attributes,
      external_file_attributes = cdfh.external_file_attributes,
      local_file_header_offset = cdfh.local_file_header_offset,
      local_file_header_position = cdfh.local_file_header_offset + start,
      header_size = size + n + m + k
    }
  end

  local function readLFH(position)
    local lfh = LFH()
    local size = ffi.sizeof(lfh)
    local data = fs.read(fd, size, position)

    ffi.copy(lfh, data, size)
    if lfh.signature ~= 0x04034b50 then
      error "Invalid LFH position"
    end
    local n, m = lfh.file_name_length, lfh.extra_field_length
    local more = fs.read(fd, n + m, position + size)

    return {
      version_needed = lfh.version_needed,
      flags = lfh.flags,
      compression_method = lfh.compression_method,
      last_mod_file_time = lfh.last_mod_file_time,
      last_mod_file_date = lfh.last_mod_file_date,
      crc_32 = lfh.crc_32,
      compressed_size = lfh.compressed_size,
      uncompressed_size = lfh.uncompressed_size,
      file_name = string.sub(more, 1, n),
      -- extra_field = string.sub(more, n + 1, n + m),
      header_size = size + n + m,
    }
  end

  local function stat(path)
    path = normalizePath(path)
    local entry = cd[path]
    if entry then return entry end
    return nil, "No such entry '" .. path .. "'"
  end

  local function readdir(path)
    path = normalizePath(path)
    if #path > 0 and not cd[path] then
      return nil, "No such directory '" .. path .. "'"
    end
    local entries = {}
    local pattern
    if #path > 0 then
      pattern = "^" .. path .. "/([^/]+)$"
    else
      pattern = "^([^/]+)$"
    end
    for name, entry in pairs(cd) do
      local a, b, match = string.find(name, pattern)
      if match then
        entries[match] = entry
      end
    end
    return entries
  end

  local function readfile(path)
    path = normalizePath(path)
    local entry = cd[path]
    if entry == nil then return nil, "No such file '" .. path .. "'" end
    local lfh = readLFH(entry.local_file_header_position)

    if entry.crc_32 ~= lfh.crc_32 or
       entry.file_name ~= lfh.file_name or
       entry.compression_method ~= lfh.compression_method or
       entry.compressed_size ~= lfh.compressed_size or
       entry.uncompressed_size ~= lfh.uncompressed_size then
      error "Local file header doesn't match entry in central directory"
    end
    local start = entry.local_file_header_position + lfh.header_size
    local compressed = fs.read(fd, lfh.compressed_size, start)
    if #compressed ~= entry.compressed_size then
      error "compressed size mismatch"
    end

    local uncompressed
    -- Store
    if lfh.compression_method == 0 then
      uncompressed = compressed
    -- Inflate
    elseif lfh.compression_method == 8 then
      uncompressed = assert(zlib.new('inflate',-15):write(compressed, 'finish'))
    else
      error("Unknown compression method: " .. lfh.compression_method)
    end
    if #uncompressed ~= lfh.uncompressed_size then
      error "uncompressed size mismatch"
    end
    return uncompressed
  end

  local function load()
    local position = findEoCD()
    if position == nil then return nil, "Can't find End of Central Directory" end
    local eocd = readEoCD(position)
    position = position - eocd.central_dir_size
    local start = position - eocd.central_dir_offset
    for i = 1, eocd.central_dir_disk_records do
      local cdfh = readCDFH(position, start)
      cd[normalizePath(cdfh.file_name)] = cdfh
      position = position + cdfh.header_size
    end

    return {
      stat = stat,
      readdir = readdir,
      readfile = readfile,
    }

  end

  return load()

end

local utils = {}

local colors = {
  black   = "0;30",
  red     = "0;31",
  green   = "0;32",
  yellow  = "0;33",
  blue    = "0;34",
  magenta = "0;35",
  cyan    = "0;36",
  white   = "0;37",
  B        = "1;",
  Bblack   = "1;30",
  Bred     = "1;31",
  Bgreen   = "1;32",
  Byellow  = "1;33",
  Bblue    = "1;34",
  Bmagenta = "1;35",
  Bcyan    = "1;36",
  Bwhite   = "1;37"
}

if utils._useColors == nil then
  utils._useColors = true
end

function utils.color(color_name)
  if utils._useColors then
    return "\27[" .. (colors[color_name] or "0") .. "m"
  else
    return ""
  end
end

function utils.colorize(color_name, string, reset_name)
  return utils.color(color_name) .. tostring(string) .. utils.color(reset_name)
end

local backslash, null, newline, carriage, tab, quote, quote2, obracket, cbracket

function utils.loadColors (n)
  if n ~= nil then utils._useColors = n end
  backslash = utils.colorize("Bgreen", "\\\\", "green")
  null      = utils.colorize("Bgreen", "\\0", "green")
  newline   = utils.colorize("Bgreen", "\\n", "green")
  carriage  = utils.colorize("Bgreen", "\\r", "green")
  tab       = utils.colorize("Bgreen", "\\t", "green")
  quote     = utils.colorize("Bgreen", '"', "green")
  quote2    = utils.colorize("Bgreen", '"')
  obracket  = utils.colorize("B", '[')
  cbracket  = utils.colorize("B", ']')
end

utils.loadColors ()

function utils.dump(o, depth)
  local t = type(o)
  if t == 'string' then
    return quote .. o:gsub("\\", backslash):gsub("%z", null):gsub("\n", newline):gsub("\r", carriage):gsub("\t", tab) .. quote2
  end
  if t == 'nil' then
    return utils.colorize("Bblack", "nil")
  end
  if t == 'boolean' then
    return utils.colorize("yellow", tostring(o))
  end
  if t == 'number' then
    return utils.colorize("blue", tostring(o))
  end
  if t == 'userdata' then
    return utils.colorize("magenta", tostring(o))
  end
  if t == 'thread' then
    return utils.colorize("Bred", tostring(o))
  end
  if t == 'function' then
    return utils.colorize("cyan", tostring(o))
  end
  if t == 'cdata' then
    return utils.colorize("Bmagenta", tostring(o))
  end
  if t == 'table' then
    if type(depth) == 'nil' then
      depth = 0
    end
    if depth > 1 then
      return utils.colorize("yellow", tostring(o))
    end
    local indent = ("  "):rep(depth)

    -- Check to see if this is an array
    local is_array = true
    local i = 1
    for k,v in pairs(o) do
      if not (k == i) then
        is_array = false
      end
      i = i + 1
    end

    local first = true
    local lines = {}
    i = 1
    local estimated = 0
    for k,v in (is_array and ipairs or pairs)(o) do
      local s
      if is_array then
        s = ""
      else
        if type(k) == "string" and k:find("^[%a_][%a%d_]*$") then
          s = k .. ' = '
        else
          s = '[' .. utils.dump(k, 100) .. '] = '
        end
      end
      s = s .. utils.dump(v, depth + 1)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
    end
    if estimated > 200 then
      return "{\n  " .. indent .. table.concat(lines, ",\n  " .. indent) .. "\n" .. indent .. "}"
    else
      return "{ " .. table.concat(lines, ", ") .. " }"
    end
  end
  -- This doesn't happen right?
  return tostring(o)
end

-- A nice global data dumper
function utils.prettyPrint(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = utils.dump(arguments[i])
  end

  io.stdout:write(table.concat(arguments, "\t") .. "\n")
end

-- prettyprint to stderr
function utils.debug(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = utils.dump(arguments[i])
  end

  io.stderr:write(table.concat(arguments, "\t") .. "\n")
end

-- local path = uv.execpath()
local p = utils.prettyPrint
local path = "sample.zip"
local fd = uv.fs_open(path, "r", tonumber("644", 8))
local zip = setup(fd, {fstat=uv.fs_fstat, read=uv.fs_read})
p(zip.readdir(""))
