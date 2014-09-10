return function(...)

  local uv = _G.uv
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

    local inflate = _G.inflate
    local fd = uv.fs_open(uv.execpath(), 'r', tonumber('644', 8))

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
    local LFH = ffi.typeof('struct zip_LFH')
    -- Central Directory File Header
    local CDFH = ffi.typeof('struct zip_CDFH')
    -- End of Central Directory
    local EoCD = ffi.typeof('struct zip_EoCD')


    local cd = {}

    -- Scan from the end of a file to find the start position of
    -- the EoCD (end of central directory) entry.
    local function findEoCD()
      local stat = uv.fs_fstat(fd)

      -- Theoretically, the comment at the end can be 0x10000 bytes long
      -- though there is no sense reading more than that.
      local maxSize = 0x10000 + 22
      local start = stat.size - maxSize
      if start < 1 then
        maxSize = stat.size
        start = 1
      end
      local tail = uv.fs_read(fd, maxSize, start)
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
      local data = uv.fs_read(fd, size, position)

      ffi.copy(eocd, data, size)

      if eocd.signature ~= 0x06054b50 then
        error 'Invalid EoCD position'
      end
      local comment = uv.fs_read(fd, eocd.file_comment_length, position + size)

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
      local data = uv.fs_read(fd, size, position)

      ffi.copy(cdfh, data, size)
      if cdfh.signature ~= 0x02014b50 then
        error 'Invalid CDFH position'
      end
      local n, m, k = cdfh.file_name_length, cdfh.extra_field_length, cdfh.file_comment_length
      local more = uv.fs_read(fd, n + m + k, position + size)

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
      local data = uv.fs_read(fd, size, position)

      ffi.copy(lfh, data, size)
      if lfh.signature ~= 0x04034b50 then
        error 'Invalid LFH position'
      end
      local n, m = lfh.file_name_length, lfh.extra_field_length
      local more = uv.fs_read(fd, n + m, position + size)

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
      return nil, 'No such entry ' .. path
    end

    local function readdir(path)
      path = normalizePath(path)
      if #path > 0 and not cd[path] then
        return nil, 'No such directory ' .. path
      end
      local entries = {}
      local pattern
      if #path > 0 then
        pattern = '^' .. path .. '/([^/]+)$'
      else
        pattern = '^([^/]+)$'
      end
      for name, entry in pairs(cd) do
        local a, b, match = string.find(name, pattern)
        if match then
          table.insert(entries, match)
        end
      end
      return entries
    end

    local function readfile(path)
      path = normalizePath(path)
      local entry = cd[path]
      if entry == nil then return nil, 'No such file ' .. path end
      local lfh = readLFH(entry.local_file_header_position)

      if entry.crc_32 ~= lfh.crc_32 or
         entry.file_name ~= lfh.file_name or
         entry.compression_method ~= lfh.compression_method or
         entry.compressed_size ~= lfh.compressed_size or
         entry.uncompressed_size ~= lfh.uncompressed_size then
        error 'Local file header doesn\'t match entry in central directory'
      end
      local start = entry.local_file_header_position + lfh.header_size
      local compressed = uv.fs_read(fd, lfh.compressed_size, start)
      if #compressed ~= entry.compressed_size then
        error 'compressed size mismatch'
      end

      local uncompressed
      -- Store
      if lfh.compression_method == 0 then
        uncompressed = compressed
      -- Inflate
      elseif lfh.compression_method == 8 then
        uncompressed = inflate(compressed)
      else
        error('Unknown compression method: ' .. lfh.compression_method)
      end
      if #uncompressed ~= lfh.uncompressed_size then
        error 'uncompressed size mismatch'
      end
      return uncompressed
    end

    local position = findEoCD()
    if position == nil then
      print("Missing bundle.  Either set LUVI_IN environment variable to path to folder or append zip to this binary")
      return 2
    end
    local eocd = readEoCD(position)
    position = position - eocd.central_dir_size
    local start = position - eocd.central_dir_offset
    for i = 1, eocd.central_dir_disk_records do
      local cdfh = readCDFH(position, start)
      cd[normalizePath(cdfh.file_name)] = cdfh
      position = position + cdfh.header_size
    end

    bundle = {
      stat = stat,
      readdir = readdir,
      readfile = readfile,
    }
  end

  _G.bundle = bundle
  local main = bundle.readfile("main.lua")
  if not main then error("Missing main.lua in bundle") end
  return loadstring(main, "bundle:main.lua")(...)

end
