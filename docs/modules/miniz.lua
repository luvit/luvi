---@alias types
---Indicates that this section represents a module.
---|'module'
---A section that consists of text only.
---|'text'
---Indicates that this section represents a class structure.
---|'class'
---Indicates that this section is a list of static functions.
---|'functions'
---Indicates that this section is a list of constant values.
---|'constants'

---@alias alias_types {type: string, value?: string, default?: boolean, description?: string}[]
---@alias alias {name: string, types: alias_types}
---@alias aliases alias[]

---@alias param {name: string, description: string, type: string, optional: boolean, omissible?: any, default?: string}
---@alias params param[]
---@alias returns {name: string, description: string, types: string, nilable?: boolean}[]
---@alias method {name: string, description: string, method_form?: string, params: params, returns: returns}
---@alias methods method[]


---@class section: table
---@field type string
---@field title string
---@field description string
---@field aliases aliases

---A section that consists of text only.
---@class text_section: section
---@field type 'text'

---A section that represents a class-like structure.
---@class class_section: section
---@field type 'class'
---@field name string
---@field parents string[]
---@field methods methods

---A section containing a list of static functions.
---@class functions_section: section
---@field type 'functions'
---An array of methods definitions.
---@field methods methods
---@field source? string

---A section containing a list of constant values.
---@class constants_section: section
---@field type 'constants'
---@field constants {name: string, type: string, value: string}[]


---@class meta: table
---The name of this docs/meta file.
---@field name string
---A title for the main section.
---@field title string
---A description for this module.
---@field description string
---The version of the module documented in this table.
---@field version string
---The version of this *documentation*.
---This is potentially useful when introducing what may be considered breaking change for tools using this file to generate docs.
---@field def_version string
---The type of the upper level section, most often a module.
---@field type types
---An array of sub-sections under module.
---@field [number] text_section | class_section | functions_section | constants_section


local fail_indicator = {
  name = 'fail',
  types = 'nil',
}
local fail_msg = {
  name = 'failure_msg',
  types = 'string',
}
local fail_group = {
  {
    fail_indicator,
    fail_msg,
  },
}

---@type meta
local meta = {
  version = '10.1.0', -- the bindings version (currently the same as miniz version)
  def_version = '1', -- an internal versioning of the definitions

  type = 'module',
  name = 'miniz',
  title = 'Miniz Bindings - lminiz',
  description = [[
Lua bindings for [miniz](https://github.com/richgel999/miniz), a minimal C library for zlib.

Using miniz you are able to create and read zlib ZIP archives, luvi uses it internally to create executable bundles.
Note this bindings depends on `luvi` and `luv` and currently can't be used outside Luvi.

For the purposes of writing and reading ZIP files take a look at `miniz.new_writer` and `miniz.new_reader`,
the rest of functions are either helpers or intended for deflate/inflate streams.

**Version:** 10.1.0.

**Available on Luvi:** `regular`, `tiny`.

**Available on platform:** All.

**Imported with:** `require('miniz')`.
]],

  {
    type = 'functions',
    title = '`miniz` — Base Module Functions',
    description = 'functions to initiate operations.',
    aliases = {
      {
        name = 'miniz.alias.mz_zip_flags',
        types = {
          {
            type = 'integer',
            value = '0x0100',
            description = 'MZ_ZIP_FLAG_CASE_SENSITIVE',
          },
          {
            type = 'integer',
            value = '0x0200',
            description = 'MZ_ZIP_FLAG_IGNORE_PATH',
          },
          {
            type = 'integer',
            value = '0x0400',
            description = 'MZ_ZIP_FLAG_COMPRESSED_DATA',
          },
          {
            type = 'integer',
            value = '0x0800',
            description = 'MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY',
          },
          {
            type = 'integer',
            value = '0x1000',
            description = 'MZ_ZIP_FLAG_VALIDATE_LOCATE_FILE_FLAG',
          },
          {
            type = 'integer',
            value = '0x2000',
            description = 'MZ_ZIP_FLAG_VALIDATE_HEADERS_ONLY',
          },
          {
            type = 'integer',
            value = '0x4000',
            description = 'MZ_ZIP_FLAG_WRITE_ZIP64',
          },
          {
            type = 'integer',
            value = '0x8000',
            description = 'MZ_ZIP_FLAG_WRITE_ALLOW_READING',
          },
          {
            type = 'integer',
            value = '0x10000',
            description = 'MZ_ZIP_FLAG_ASCII_FILENAME',
          },
        },
      },
      {
        name = 'miniz.alias.tinfl_decompression_flags',
        types = {
          {
            type = 'integer',
            value = '1',
            description = 'TINFL_FLAG_PARSE_ZLIB_HEADER - If set, the input has a valid zlib header and ends with an adler32 checksum (it\'s a valid zlib stream). Otherwise, the input is a raw deflate stream.',
          },
          {
            type = 'integer',
            value = '2',
            description = 'TINFL_FLAG_HAS_MORE_INPUT - If set, there are more input bytes available beyond the end of the supplied input buffer. If clear, the input buffer contains all remaining input.',
          },
          {
            type = 'integer',
            value = '4',
            description = 'TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF - If set, the output buffer is large enough to hold the entire decompressed stream. If clear, the output buffer is at least the size of the dictionary (typically 32KB).',
          },
          {
            type = 'integer',
            value = '8',
            description = 'TINFL_FLAG_COMPUTE_ADLER32 - Force adler-32 checksum computation of the decompressed bytes.',
          },
        },
      },
    },
    methods = {
      {
        name = 'new_reader',
        description = 'Creates a new miniz reader.',
        params = {
          {
            name = 'path',
            description = 'The path to the archive file the reader will read from.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flags',
            description = 'miniz initialization flags.',
            type = '@miniz.alias.mz_zip_flags',
            optional = true,
            default = '0',
          },
        },
        returns = {
          {
            name = 'zip_reader',
            types = 'miniz_reader',
          },
          unpack(fail_group),
        },
      },
      {
        name = 'new_writer',
        description = 'Creates a new miniz writer.',
        params = {
          {
            name = 'reserved_size',
            description = 'The size (in bytes) at the archive beginning for miniz to reserve. Effectively offsets the actual beginning of the archive.',
            type = 'integer',
            optional = true,
            default = '0',
          },
          {
            name = 'initial_allocation_size',
            description = [[
The archive size (in bytes) to allocate at initialization.
This is not the final size of the archive just the initial allocation,
set this if you have a good estimation about the archive size and you want to avoid unnecessary allocations.
]],
            type = 'integer',
            optional = true,
            default = '131072',
          },
        },
        returns = {
          {
            name = 'zip_writer',
            types = 'miniz_writer',
            nilable = false,
          },
        },
        errors = true,
      },
      {
        name = 'inflate',
        description = 'Inflates (decompresses) the input string into memory.\nThis operates on raw deflated data and not on a zlib format / ZIP archives, for that use `miniz.uncompress` / `miniz.new_reader` respectively.',
        params = {
          {
            name = 'data',
            description = 'The input buffer to inflate.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flags',
            description = 'miniz decompression flags.',
            type = '@miniz.alias.tinfl_decompression_flags',
            optional = true,
            default = '0',
          },
        },
        returns = {
          {
            name = 'inflated_data',
            description = 'The inflated/decompressed data as a Lua string.',
            types = 'string',
            nilable = false,
          }
        },
      },
      {
        name = 'deflate',
        description = 'Deflates (compresses) the input data into memory.\nThe output of this is the deflated binary and not a valid zlib/ZIP on its own, for that use `miniz.compress` / `miniz.new_writer` respectively.',
        params = {
          {
            name = 'data',
            description = 'The input buffer to deflate.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flags',
            description = 'Miniz compression flags.',
            type = '@miniz.alias.mz_zip_flags',
            optional = true,
          },
        },
        returns = {
          {
            name = 'deflated_data',
            description = 'The deflated/compressed data as a Lua string.',
            types = 'string',
            nilable = false,
          },
        },
      },
      {
        name = 'adler32',
        description = 'Calculates the Adler32 checksum of the provided string.',
        params = {
          {
            name = 'adler',
            description = 'The initial Adler32 checksum. More specifically this is first 16-bit A-portion of the checksum.',
            type = 'integer',
            optional = true,
            default = '1',
          },
          {
            name = 'data',
            description = 'The data to calculate the checksum for.',
            type = 'string',
            optional = true,
          },
        },
        returns = {
          {
            name = 'checksum',
            description = 'The calculated Adler32 checksum.',
            types = 'integer',
            nilable = false,
          },
        },
      },
      {
        name = 'crc32',
        description = 'Calculates the CRC32 checksum of the provided string.',
        params = {
          {
            name = 'crc32',
            description = 'An initial CRC32 checksum.',
            type = 'integer',
            optional = true,
            default = '0',
          },
          {
            name = 'data',
            description = 'The data to calculate the checksum for.',
            type = 'string',
            optional = true,
          },
        },
        returns = {
          {
            name = 'checksum',
            description = 'The calculated CRC32 checksum.',
            types = 'integer',
            nilable = false,
          },
        },
      },
      {
        name = 'compress',
        description = 'Compress the input string in zlib format.\nUnlike deflate, this will compress the data in a single call and output zlib-format, this is still not a ZIP archive, for that use `miniz.new_writer`.',
        params = {
          {
            name = 'data',
            description = 'The input data to compress.',
            type = 'string',
            optional = false,
          },
          {
            name = 'compression_level',
            description = 'Determines the speed to compression ratio, the higher this value is the better compression and the slower it is.\nAllowed values are between 1-9.',
            type = 'integer',
            optional = true,
          },
        },
        returns = {
          {
            name = 'output',
            description = 'The zlib compressed data.',
            types = 'string',
            nilable = true,
          },
          unpack(fail_group),
        },
        errors = true,
      },
      {
        name = 'uncompress',
        description = 'Decompress zlib compressed data.\nUnlike inflate, this will decompress the data in a single call assuming the input is in zlib-format. For unzipping files use `miniz.new_reader` instead.',
        params = {
          {
            name = 'data',
            description = 'The input data to decompress.',
            type = 'string',
            optional = false,
          },
          {
            name = 'initial_allocation',
            description = [[
The initial size (in bytes) to allocate for the output buffer.
This is not the final size of the output just the initial allocation,
set this if you have a good estimation and you want to avoid unnecessary allocations.]],
            type = 'integer',
            default = '#data * 2',
          },
        },
        returns = {
          {
            name = 'output',
            description = 'The uncompressed data.',
            types = 'string',
            nilable = true,
          },
          unpack(fail_group),
          errors = true,
        },
      },
      {
        name = 'version',
        description = 'Returns the miniz version.',
        params = {},
        returns = {
          {
            name = 'version',
            description = 'The miniz version.',
            types = 'string',
            nilable = false,
          },
        },
      },
      {
        name = 'new_deflator',
        description = 'Creates a new miniz_deflator stream.',
        params = {
          {
            name = 'compression_level',
            description = 'Determines the speed to compression ratio, the higher this value is the better compression and the slower it is.\nAllowed values are between 1-9.',
            type = 'integer',
            optional = true,
          },
        },
        returns = {
          {
            name = 'stream',
            description = 'The miniz deflator stream.',
            types = 'miniz_deflator',
            nilable = false,
          },
        },
        errors = true,
      },
      {
        name = 'new_inflator',
        description = 'Creates a new miniz_inflator stream.',
        params = {},
        returns = {
          {
            name = 'stream',
            description = 'The miniz deflator stream.',
            types = 'miniz_deflator',
            nilable = false,
          },
        },
        errors = true,
      },
    }
  },

  {
    type = 'class',
    name = 'miniz_reader',
    title = '`miniz_reader` — Read archive from a file',
    description = 'Initialize a reader for reading ZIP files and archives from a path.',
    parents = {},
    aliases = {
      {
        name = 'miniz.alias.mz_zip_archive_file_stat',
        types = {
          {
            type = 'table',
            value = '{index: integer, version_made_by: integer, version_needed: integer, bit_flag: integer, method: integer, time: integer, crc32: integer, comp_size: integer, uncom_size: integer, internal_attr: integer, external_attr: integer, filename: string, comment: string}',
          },
        },
      },
    },
    methods = {
      {
        name = 'get_num_files',
        description = 'Returns the number of archived files.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
        },
        returns = {
          {
            name = 'files',
            description = 'the count of available files inside the archive.',
            types = 'integer',
            nilable = false,
          },
        },
      },
      {
        name = 'stat',
        description = 'Returns the stats of a file/directory inside the archive.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
          {
            name = 'file_index',
            description = 'A 1-based index of the desired entry.',
            optional = false,
            type = 'integer',
          },
        },
        returns = {
          {
            name = 'stats',
            description = 'The file stats.',
            types = '@miniz.alias.mz_zip_archive_file_stat',
            nilable = false,
          },
          unpack(fail_group),
        },
      },
      {
        name = 'get_filename',
        description = 'Returns the file/directory name archived at a specific index.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
          {
            name = 'file_index',
            description = 'A 1-based index of the desired entry.',
            optional = false,
            type = 'integer',
          },
        },
        returns = {
          {
            name = 'filename',
            description = 'The name of the file at file_index.',
            types = 'string',
            nilable = true,
          },
          unpack(fail_group),
        },
      },
      {
        name = 'is_directory',
        description = 'Returns whether or not the entry at a specified index is a directory.\nNote: Unlike other methods, this will return `false` if the index provided does not exists.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
          {
            name = 'file_index',
            description = 'A 1-based index of the desired entry.',
            optional = false,
            type = 'integer',
          },
        },
        returns = {
          {
            name = 'is_directory',
            description = 'whether or not the entry is a directory.',
            types = 'boolean',
            nilable = false,
          },
        },
      },
      {
        name = 'extract',
        description = 'Extracts an entry into a Lua string.\nNote: Unlike other methods, if the index does not exists this will return an empty string.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
          {
            name = 'file_index',
            description = 'A 1-based index of the desired entry.',
            optional = false,
            type = 'integer',
          },
          {
            name = 'flags',
            description = 'Extraction flags.',
            type = '@miniz.alias.mz_zip_flags',
            optional = true,
          },
        },
        returns = {
          {
            name = 'extracted',
            description = 'The extracted entry as a Lua string, empty string if the entry is a directory or doesn\'t exists',
            types = 'string',
            nilable = false,
          },
        },
      },
      {
        name = 'locate_file',
        description = 'Given the path of a file, return its index.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
          {
            name = 'path',
            description = 'The file path to locate.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flags',
            description = 'Locate flags. Available flags are `MZ_ZIP_FLAG_IGNORE_PATH, MZ_ZIP_FLAG_CASE_SENSITIVE`.',
            type = '@miniz.alias.mz_zip_flags',
            optional = true,
          },
        },
        returns = {
          {
            name = 'index',
            description = 'The located index if found.',
            types = 'integer',
            nilable = true,
          },
          unpack(fail_group),
        },
      },
      {
        name = 'get_offset',
        description = 'If the archive does not start at the beginning of the ZIP, returns the offset (in bytes) at which the archive starts.',
        method_form = 'reader',
        params = {
          {
            name = 'reader',
            type = 'miniz_reader',
            optional = false,
          },
        },
        returns = {
          {
            name = 'offset',
            description = 'The offset at which the archive start in bytes.',
            types = 'integer',
            nilable = false,
          },
        },
      },
    },
  },

  {
    type = 'class',
    name = 'miniz_writer',
    title = '`miniz_writer` — Write archives to a file',
    description = 'Initialize a writer to create a new zlib archive.',
    parents = {},
    aliases = {},
    methods = {
      {
        name = 'add_from_zip',
        description = 'Copy a file from miniz_reader `source`.',
        method_form = 'writer',
        params = {
          {
            name = 'writer',
            type = 'miniz_writer',
            optional = false,
          },
          {
            name = 'source',
            description = 'The archive from which to copy the file.',
            optional = false,
            type = 'miniz_reader',
          },
          {
            name = 'file_index',
            description = 'A 1-based index of the desired entry.',
            optional = false,
            type = 'integer',
          },
        },
        returns = {},
        errors = true,
      },
      {
        name = 'add',
        description = 'Add a new entry at the specified path.\nNote: By default the compression level is set to 0.',
        method_form = 'writer',
        params = {
          {
            name = 'writer',
            type = 'miniz_writer',
            optional = false,
          },
          {
            name = 'path',
            description = 'The path in the central directory (the archive) to add the data to.',
            type = 'string',
            optional = false,
          },
          {
            name = 'data',
            description = 'The data that will be compressed and added into the archive',
            type = 'string',
            optional = false,
          },
          {
            name = 'level_and_flags',
            description = 'The compression level, this is a number between 0-10, you may OR this with one of the `mz_zip_flags` flag values.',
            type = 'integer',
            optional = true,
            default = '0',
          },
        },
        returns = {},
        errors = true,
      },
      {
        name = 'finalize',
        description = 'ZLIB encode and compress all of the added entries and output it into a string.',
        method_form = 'writer',
        params = {
          {
            name = 'writer',
            type = 'miniz_writer',
            optional = false,
          },
        },
        returns = {
          {
            name = 'zip',
            description = 'The archive binary data.',
            types = 'string',
            nilable = false,
          },
        },
        errors = true,
      },
    },
  },

  {
    type = 'class',
    name = 'miniz_deflator',
    title = '`miniz_deflator` — Deflate a stream of data',
    description = 'Apply deflate on a stream of data.\nIn order to finalize the deflated data set `flush` to `"finish"`.\nNote: In case of an error, this will return a `fail`, and the deflated buffer.',
    parents = {},
    aliases = {
      {
        name = 'miniz.alias.flush_values',
        types = {
          {
            type = 'string',
            value = '"no"',
            description = 'Do no flushing on this call.',
            default = true,
          },
          {
            type = 'string',
            value = '"partial"',
          },
          {
            type = 'string',
            value = '"sync"',
          },
          {
            type = 'string',
            value = '"full"',
          },
          {
            type = 'string',
            value = '"finish"',
            description = 'Finalize the data and flush it.',
          },
          {
            type = 'string',
            value = '"block"',
          },
        }
      },
    },
    methods = {
      {
        name = 'deflate',
        description = 'Apply deflate on provided data chunk.',
        method_form = 'deflator',
        params = {
          {
            name = 'deflator',
            type = 'miniz_deflator',
            optional = false,
          },
          {
            name = 'data',
            description = 'The data to deflate.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flush',
            description = 'Whether or not to flush, and the type of flushing.',
            type = '@miniz.alias.flush_values',
            optional = true,
          },
        },
        returns = {
          {
            name = 'deflated',
            description = 'The flushed deflated data.',
            types = 'string',
            nilable = true,
          },
          {
            fail_indicator,
            fail_msg,
            {
              name = 'error_deflated',
              description = 'When an error occurs, this will be the remainder of deflated data buffer before the failed deflate.',
              types = 'string',
              nilable = false,
            },
          },
        },
      },
    },
  },

  {
    type = 'class',
    name = 'miniz_inflator',
    title = 'miniz_inflator` — Inflate a stream of data',
    description = 'Apply inflate on a stream of data.\nIn order to finalize the inflated data set `flush` to `"finish"`.\nNote: In case of an error, this will return a `fail`, and the inflate buffer.',
    parents = {},
    aliases = {},
    methods = {
      {
        name = 'inflate',
        description = 'Apply inflate on provided data chunk.',
        method_form = 'inflator',
        params = {
          {
            name = 'inflator',
            type = 'miniz_inflator',
            optional = false,
          },
          {
            name = 'data',
            description = 'The data to inflate.',
            type = 'string',
            optional = false,
          },
          {
            name = 'flush',
            description = 'Whether or not to flush, and the type of flushing.',
            type = '@miniz.alias.flush_values',
            optional = true,
          },
        },
        returns = {
          {
            name = 'inflated',
            description = 'The flushed inflated data.',
            types = 'string',
            nilable = true,
          },
          {
            fail_indicator,
            fail_msg,
            {
              name = 'error_inflated',
              description = 'When an error occurs, this will be the remainder of inflated data buffer before the failed inflate.',
              types = 'string',
              nilable = false,
            },
          },
        },
      },
    },
  },
}

return meta
