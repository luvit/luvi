--- @meta

--- @class miniz.inflate.options
--- @field zlib? boolean If true, the input is expected to be in zlib format. Defaults to false.

--- @class miniz.deflate.options
--- @field zlib? boolean If true, the output will be in zlib format. Defaults to false.
--- @field probes? integer The number of dictionary probes per search. Defaults to 128. The log2 of this value is the compression level.
--- @field filter_matches? boolean If true, the deflator will filter out matches that are too small to be worth encoding. Defaults to true.
--- @field force_static? boolean If true, the deflator will always use static Huffman codes. Defaults to false.
--- @field force_raw? boolean If true, the deflator will always use uncompressed blocks. Defaults to false.

--- @class miniz.locate_file.options
--- @field case_sensitive? boolean If true, the file name will be matched case-sensitively. Defaults to false.
--- @field ignore_path? boolean If true, the file name will be matched without considering the path. Defaults to false.

--- @class miniz.stat
--- @field index integer The index of the file in the ZIP archive.
--- @field version_made_by integer The version of the ZIP specification used to create the file.
--- @field version_needed integer The minimum version of the ZIP specification needed to extract the file.
--- @field bit_flag integer The general purpose bit flag of the file.
--- @field method integer The compression method used for the file.
--- @field time integer The modification time of the file.
--- @field crc32 integer The CRC-32 checksum of the file.
--- @field comp_size integer The size of the compressed data of the file.
--- @field uncomp_size integer The size of the uncompressed data of the file.
--- @field internal_attr integer The internal attribute of the file.
--- @field external_attr integer The external attribute of the file.
--- @field filename string The name of the file, may be truncated. Use `get_filename` to get the full name.
--- @field comment string The comment associated with the file, may be truncated.
--- @field is_directory boolean Whether the file is a directory.

--- @alias miniz.flush 'no'|'partial'|'sync'|'full'|'finish'|'block'

--- @class miniz
local miniz = {}

--- Creates a new ZIP reader for the file at the given path.
--- @param path string
--- @param flags? integer The flags to use when opening the file. Defaults to 0.
--- @return miniz.reader|nil reader
--- @return string|nil err
function miniz.new_reader(path, flags) end

--- Creates a new ZIP writer in memory.
--- @param initial_reserve_size? integer The space reserved before the archive. Defaults to 0.
--- @param initial_allocation_size? integer The initial size of the output buffer. Defaults to 128KB.
--- @return miniz.writer writer
function miniz.new_writer(initial_reserve_size, initial_allocation_size) end

--- Inflate the given compressed data.
--- @param data string
--- @param options? integer|miniz.inflate.options
--- @return string|nil output
function miniz.inflate(data, options) end

--- Deflate the given uncompressed data.
--- @param data string
--- @param options? integer|miniz.deflate.options
--- @return string|nil output
function miniz.deflate(data, options) end

--- Calculate the Adler-32 checksum of the given data, starting with the given initial value.
--- @param adler integer|nil The initial value of the checksum. Defaults to 1.
--- @param data string|nil The data to calculate the checksum of.
--- @return integer adler32 The resulting checksum.
function miniz.adler32(adler, data) end

--- Calculate the CCITT CRC-32 checksum of the given data, starting with the given initial value.
--- @param crc32 integer|nil The initial value of the checksum. Defaults to 0.
--- @param data string|nil The data to calculate the checksum of.
--- @return integer crc32 The resulting checksum.
function miniz.crc32(crc32, data) end

--- ZLIB compress the given data with the given compression level.
--- @param data string
--- @param level? integer The compression level, from 0 (no compression) to 9 (best compression). Defaults to 6.
--- @return string|nil output
--- @return string|nil err
function miniz.compress(data, level) end

--- ZLIB uncompress the given data, starting with the given initial length.
--- @param data string
--- @param initial_length? integer The initial length of the uncompressed data. Defaults to the length of the compressed data multiplied by 2.
--- @return string|nil output
--- @return string|integer err_or_processed The number of bytes processed from the input, or an error message if the decompression failed.
function miniz.uncompress(data, initial_length) end

--- Returns the version of miniz being used.
--- @return string version
function miniz.version() end

--- Creates a new ZLIB deflate stream.
--- @param level? integer The compression level, from 0 (no compression) to 9 (best compression). Defaults to 6.
--- @return miniz.deflator deflator
function miniz.new_deflator(level) end

--- Creates a new ZLIB inflate stream.
--- @return miniz.inflator inflator
function miniz.new_inflator() end

--- @class miniz.reader
local reader = {}

--- Returns the total number of files in the ZIP archive.
--- @return integer num_files
function reader:get_num_files() end

--- Returns the index of the file in the ZIP archive that matches the given path and options, or nil.
--- @param path string The path of the file to locate.
--- @param options? integer|miniz.locate_file.options
--- @return integer|nil file_index
--- @return string|nil err
function reader:locate_file(path, options) end

--- Returns the stat of the file at the given index.
--- @param file_index integer The index of the file to get the name of.
--- @return miniz.stat|nil stat
--- @return string|nil err
function reader:stat(file_index) end

--- Returns the full name of the file at the given index.
--- @param file_index integer The index of the file to get the name of.
--- @return string|nil filename
--- @return string|nil err
function reader:get_filename(file_index) end

--- Returns true if the file at the given index is a directory, false otherwise.
--- @param file_index integer The index of the file to check.
--- @return boolean is_directory
function reader:is_directory(file_index) end

--- Extracts the data of the file at the given index.
--- @param file_index integer The index of the file to extract.
--- @param flags? integer The flags to use when extracting the file. Defaults to 0.
--- @return string|nil data
--- @return string|nil err
function reader:extract(file_index, flags) end

--- Returns the offset of the archive from the start of the file.
--- @return integer offset
function reader:get_offset() end

--- @class miniz.writer
local writer = {}

--- Copy a file from an existing ZIP archive into this one.
--- @param source miniz.reader The ZIP reader to copy from.
--- @param file_index integer The index of the file to copy from the source ZIP archive.
function writer:add_from_zip(source, file_index) end

--- Add a file to the ZIP archive.
--- @param path string The path of the file to add.
--- @param data string The data of the file to add.
--- @param level_and_flags? integer The compression level and flags.
--- @param time? integer The modification time of the file.
function writer:add(path, data, level_and_flags, time) end

--- Finalize the ZIP archive and return the resulting data. After calling this method, the writer should not be used anymore.
--- @return string output
function writer:finalize() end

--- A stream-oriented zlib decompressor. This can be more efficient when dealing with large data in chunks.
--- @class miniz.inflator
local inflator = {}

--- Inflate the given compressed data, optionally flushing the stream with the given flush mode.
--- @param data string
--- @param flush? miniz.flush The flush mode to use for this inflate operation. Defaults to 'no'.
--- @return string|nil output
--- @return string|nil err
--- @return integer processed The number of bytes processed from the input.
function inflator:inflate(data, flush) end

--- A stream-oriented zlib compressor. This can be more efficient when dealing with large data in chunks.
--- @class miniz.deflator
local deflator = {}

--- Deflate the given uncompressed data, optionally flushing the stream with the given flush mode.
--- @param data string
--- @param flush? miniz.flush The flush mode to use for this deflate operation. Defaults to 'no'.
--- @return string|nil output
--- @return string|nil err
--- @return integer processed The number of bytes processed from the input.
function deflator:deflate(data, flush) end

return miniz
