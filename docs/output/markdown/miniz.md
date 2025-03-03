# Miniz Bindings - lminiz

Lua bindings for [miniz](https://github.com/richgel999/miniz), a minimal C library for zlib.

Using miniz you are able to create and read zlib ZIP archives, luvi uses it internally to create executable bundles.
Note this bindings depends on `luvi` and `luv` and currently can't be used outside Luvi.

For the purposes of writing and reading ZIP files take a look at `miniz.new_writer` and `miniz.new_reader`,
the rest of functions are either helpers or intended for deflate/inflate streams.

**Version:** 10.1.0.

**Available on Luvi:** `regular`, `tiny`.

**Available on platform:** All.

**Imported with:** `require('miniz')`.


## `miniz` — Base Module Functions

functions to initiate operations.

### `miniz.new_reader(path[, flags])`

**Parameters:**
- `path`: `string` — The path to the archive file the reader will read from.
- `flags`: `integer` or `nil` — miniz initialization flags.(default: `0`)
	- `0x0100` — MZ_ZIP_FLAG_CASE_SENSITIVE
	- `0x0200` — MZ_ZIP_FLAG_IGNORE_PATH
	- `0x0400` — MZ_ZIP_FLAG_COMPRESSED_DATA
	- `0x0800` — MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY
	- `0x1000` — MZ_ZIP_FLAG_VALIDATE_LOCATE_FILE_FLAG
	- `0x2000` — MZ_ZIP_FLAG_VALIDATE_HEADERS_ONLY
	- `0x4000` — MZ_ZIP_FLAG_WRITE_ZIP64
	- `0x8000` — MZ_ZIP_FLAG_WRITE_ALLOW_READING
	- `0x10000` — MZ_ZIP_FLAG_ASCII_FILENAME

Creates a new miniz reader.

**Returns**: `miniz_reader` or `nil, string`


### `miniz.new_writer([reserved_sizeinitial_allocation_size])`

**Parameters:**
- `reserved_size`: `integer` or `nil` — The size (in bytes) at the archive beginning for miniz to reserve. Effectively offsets the actual beginning of the archive.(default: `0`)
- `initial_allocation_size`: `integer` or `nil` — The archive size (in bytes) to allocate at initialization.
This is not the final size of the archive just the initial allocation,
set this if you have a good estimation about the archive size and you want to avoid unnecessary allocations.
(default: `131072`)

Creates a new miniz writer.

**Returns**: `miniz_writer`


### `miniz.inflate(data[, flags])`

**Parameters:**
- `data`: `string` — The input buffer to inflate.
- `flags`: `integer` or `nil` — miniz decompression flags.(default: `0`)
	- `1` — TINFL_FLAG_PARSE_ZLIB_HEADER - If set, the input has a valid zlib header and ends with an adler32 checksum (it's a valid zlib stream). Otherwise, the input is a raw deflate stream.
	- `2` — TINFL_FLAG_HAS_MORE_INPUT - If set, there are more input bytes available beyond the end of the supplied input buffer. If clear, the input buffer contains all remaining input.
	- `4` — TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF - If set, the output buffer is large enough to hold the entire decompressed stream. If clear, the output buffer is at least the size of the dictionary (typically 32KB).
	- `8` — TINFL_FLAG_COMPUTE_ADLER32 - Force adler-32 checksum computation of the decompressed bytes.

Inflates (decompresses) the input string into memory.
This operates on raw deflated data and not on a zlib format / ZIP archives, for that use `miniz.uncompress` / `miniz.new_reader` respectively.

**Returns**: `string`


### `miniz.deflate(data[, flags])`

**Parameters:**
- `data`: `string` — The input buffer to deflate.
- `flags`: `integer` or `nil` — Miniz compression flags.
	- `0x0100` — MZ_ZIP_FLAG_CASE_SENSITIVE
	- `0x0200` — MZ_ZIP_FLAG_IGNORE_PATH
	- `0x0400` — MZ_ZIP_FLAG_COMPRESSED_DATA
	- `0x0800` — MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY
	- `0x1000` — MZ_ZIP_FLAG_VALIDATE_LOCATE_FILE_FLAG
	- `0x2000` — MZ_ZIP_FLAG_VALIDATE_HEADERS_ONLY
	- `0x4000` — MZ_ZIP_FLAG_WRITE_ZIP64
	- `0x8000` — MZ_ZIP_FLAG_WRITE_ALLOW_READING
	- `0x10000` — MZ_ZIP_FLAG_ASCII_FILENAME

Deflates (compresses) the input data into memory.
The output of this is the deflated binary and not a valid zlib/ZIP on its own, for that use `miniz.compress` / `miniz.new_writer` respectively.

**Returns**: `string`


### `miniz.adler32([adlerdata])`

**Parameters:**
- `adler`: `integer` or `nil` — The initial Adler32 checksum. More specifically this is first 16-bit A-portion of the checksum.(default: `1`)
- `data`: `string` or `nil` — The data to calculate the checksum for.

Calculates the Adler32 checksum of the provided string.

**Returns**: `integer`


### `miniz.crc32([crc32data])`

**Parameters:**
- `crc32`: `integer` or `nil` — An initial CRC32 checksum.(default: `0`)
- `data`: `string` or `nil` — The data to calculate the checksum for.

Calculates the CRC32 checksum of the provided string.

**Returns**: `integer`


### `miniz.compress(data[, compression_level])`

**Parameters:**
- `data`: `string` — The input data to compress.
- `compression_level`: `integer` or `nil` — Determines the speed to compression ratio, the higher this value is the better compression and the slower it is.
Allowed values are between 1-9.

Compress the input string in zlib format.
Unlike deflate, this will compress the data in a single call and output zlib-format, this is still not a ZIP archive, for that use `miniz.new_writer`.

**Returns**: `string?` or `nil, string`


### `miniz.uncompress(data, initial_allocation)`

**Parameters:**
- `data`: `string` — The input data to decompress.
- `initial_allocation`: `integer` — The initial size (in bytes) to allocate for the output buffer.
This is not the final size of the output just the initial allocation,
set this if you have a good estimation and you want to avoid unnecessary allocations.(default: `#data * 2`)

Decompress zlib compressed data.
Unlike inflate, this will decompress the data in a single call assuming the input is in zlib-format. For unzipping files use `miniz.new_reader` instead.

**Returns**: `string?` or `nil, string`


### `miniz.version()`

Returns the miniz version.

**Returns**: `string`


### `miniz.new_deflator([compression_level])`

**Parameters:**
- `compression_level`: `integer` or `nil` — Determines the speed to compression ratio, the higher this value is the better compression and the slower it is.
Allowed values are between 1-9.

Creates a new miniz_deflator stream.

**Returns**: `miniz_deflator`


### `miniz.new_inflator()`

Creates a new miniz_inflator stream.

**Returns**: `miniz_deflator`


## `miniz_reader` — Read archive from a file

Initialize a reader for reading ZIP files and archives from a path.

### `miniz_reader.get_num_files(reader)`

> method form  `reader:get_num_files(reader)`

**Parameters:**
- `reader`: `miniz_reader` 

Returns the number of archived files.

**Returns**: `integer`


### `miniz_reader.stat(reader, file_index)`

> method form  `reader:stat(reader, file_index)`

**Parameters:**
- `reader`: `miniz_reader` 
- `file_index`: `integer` — A 1-based index of the desired entry.

Returns the stats of a file/directory inside the archive.

**Returns**: `table` or `nil, string`
- `comp_size`: `integer`
- `uncom_size`: `integer`
- `index`: `integer`
- `external_attr`: `integer`
- `comment`: `string`
- `crc32`: `integer`
- `filename`: `string`
- `time`: `integer`
- `internal_attr`: `integer`
- `version_made_by`: `integer`
- `version_needed`: `integer`
- `bit_flag`: `integer`
- `method`: `integer`


### `miniz_reader.get_filename(reader, file_index)`

> method form  `reader:get_filename(reader, file_index)`

**Parameters:**
- `reader`: `miniz_reader` 
- `file_index`: `integer` — A 1-based index of the desired entry.

Returns the file/directory name archived at a specific index.

**Returns**: `string?` or `nil, string`


### `miniz_reader.is_directory(reader, file_index)`

> method form  `reader:is_directory(reader, file_index)`

**Parameters:**
- `reader`: `miniz_reader` 
- `file_index`: `integer` — A 1-based index of the desired entry.

Returns whether or not the entry at a specified index is a directory.
Note: Unlike other methods, this will return `false` if the index provided does not exists.

**Returns**: `boolean`


### `miniz_reader.extract(reader, file_index[, flags])`

> method form  `reader:extract(reader, file_index[, flags])`

**Parameters:**
- `reader`: `miniz_reader` 
- `file_index`: `integer` — A 1-based index of the desired entry.
- `flags`: `integer` or `nil` — Extraction flags.
	- `0x0100` — MZ_ZIP_FLAG_CASE_SENSITIVE
	- `0x0200` — MZ_ZIP_FLAG_IGNORE_PATH
	- `0x0400` — MZ_ZIP_FLAG_COMPRESSED_DATA
	- `0x0800` — MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY
	- `0x1000` — MZ_ZIP_FLAG_VALIDATE_LOCATE_FILE_FLAG
	- `0x2000` — MZ_ZIP_FLAG_VALIDATE_HEADERS_ONLY
	- `0x4000` — MZ_ZIP_FLAG_WRITE_ZIP64
	- `0x8000` — MZ_ZIP_FLAG_WRITE_ALLOW_READING
	- `0x10000` — MZ_ZIP_FLAG_ASCII_FILENAME

Extracts an entry into a Lua string.
Note: Unlike other methods, if the index does not exists this will return an empty string.

**Returns**: `string`


### `miniz_reader.locate_file(reader, path[, flags])`

> method form  `reader:locate_file(reader, path[, flags])`

**Parameters:**
- `reader`: `miniz_reader` 
- `path`: `string` — The file path to locate.
- `flags`: `integer` or `nil` — Locate flags. Available flags are `MZ_ZIP_FLAG_IGNORE_PATH, MZ_ZIP_FLAG_CASE_SENSITIVE`.
	- `0x0100` — MZ_ZIP_FLAG_CASE_SENSITIVE
	- `0x0200` — MZ_ZIP_FLAG_IGNORE_PATH
	- `0x0400` — MZ_ZIP_FLAG_COMPRESSED_DATA
	- `0x0800` — MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY
	- `0x1000` — MZ_ZIP_FLAG_VALIDATE_LOCATE_FILE_FLAG
	- `0x2000` — MZ_ZIP_FLAG_VALIDATE_HEADERS_ONLY
	- `0x4000` — MZ_ZIP_FLAG_WRITE_ZIP64
	- `0x8000` — MZ_ZIP_FLAG_WRITE_ALLOW_READING
	- `0x10000` — MZ_ZIP_FLAG_ASCII_FILENAME

Given the path of a file, return its index.

**Returns**: `integer?` or `nil, string`


### `miniz_reader.get_offset(reader)`

> method form  `reader:get_offset(reader)`

**Parameters:**
- `reader`: `miniz_reader` 

If the archive does not start at the beginning of the ZIP, returns the offset (in bytes) at which the archive starts.

**Returns**: `integer`


## `miniz_writer` — Write archives to a file

Initialize a writer to create a new zlib archive.

### `miniz_writer.add_from_zip(writer, source, file_index)`

> method form  `writer:add_from_zip(writer, source, file_index)`

**Parameters:**
- `writer`: `miniz_writer` 
- `source`: `miniz_reader` — The archive from which to copy the file.
- `file_index`: `integer` — A 1-based index of the desired entry.

Copy a file from miniz_reader `source`.

**Returns**: Nothing.

### `miniz_writer.add(writer, path, data[, level_and_flags])`

> method form  `writer:add(writer, path, data[, level_and_flags])`

**Parameters:**
- `writer`: `miniz_writer` 
- `path`: `string` — The path in the central directory (the archive) to add the data to.
- `data`: `string` — The data that will be compressed and added into the archive
- `level_and_flags`: `integer` or `nil` — The compression level, this is a number between 0-10, you may OR this with one of the `mz_zip_flags` flag values.(default: `0`)

Add a new entry at the specified path.
Note: By default the compression level is set to 0.

**Returns**: Nothing.

### `miniz_writer.finalize(writer)`

> method form  `writer:finalize(writer)`

**Parameters:**
- `writer`: `miniz_writer` 

ZLIB encode and compress all of the added entries and output it into a string.

**Returns**: `string`


## `miniz_deflator` — Deflate a stream of data

Apply deflate on a stream of data.
In order to finalize the deflated data set `flush` to `"finish"`.
Note: In case of an error, this will return a `fail`, and the deflated buffer.

### `miniz_deflator.deflate(deflator, data[, flush])`

> method form  `deflator:deflate(deflator, data[, flush])`

**Parameters:**
- `deflator`: `miniz_deflator` 
- `data`: `string` — The data to deflate.
- `flush`: `string` or `nil` — Whether or not to flush, and the type of flushing.
	- `"no"` (default) — Do no flushing on this call.
	- `"partial"`
	- `"sync"`
	- `"full"`
	- `"finish"` — Finalize the data and flush it.
	- `"block"`

Apply deflate on provided data chunk.

**Returns**: `string?` or `nil, string, string`


## miniz_inflator` — Inflate a stream of data

Apply inflate on a stream of data.
In order to finalize the inflated data set `flush` to `"finish"`.
Note: In case of an error, this will return a `fail`, and the inflate buffer.

### `miniz_inflator.inflate(inflator, data[, flush])`

> method form  `inflator:inflate(inflator, data[, flush])`

**Parameters:**
- `inflator`: `miniz_inflator` 
- `data`: `string` — The data to inflate.
- `flush`: `string` or `nil` — Whether or not to flush, and the type of flushing.
	- `"no"` (default) — Do no flushing on this call.
	- `"partial"`
	- `"sync"`
	- `"full"`
	- `"finish"` — Finalize the data and flush it.
	- `"block"`

Apply inflate on provided data chunk.

**Returns**: `string?` or `nil, string, string`


