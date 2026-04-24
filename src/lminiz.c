/*
 *  Copyright 2014 The Luvit Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include <time.h>
#include "./luvi.h"
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "../deps/miniz/miniz.h"

static int lmz_check_compression_level(lua_State* L, int index) {
  int level = luaL_optinteger(L, index, MZ_DEFAULT_LEVEL);
  if (level < MZ_NO_COMPRESSION || level > MZ_BEST_COMPRESSION) {
    return luaL_argerror(L, index, "compression level must be between 0 and 9");
  }
  return level;
}

static int lmz_reader_init(lua_State* L) {
  const char* path = luaL_checkstring(L, 1);
  mz_uint32 flags = luaL_optinteger(L, 2, 0);

  mz_zip_archive* archive = lua_newuserdata(L, sizeof(*archive));
  memset(archive, 0, sizeof(*archive));

  luaL_getmetatable(L, "miniz_reader");
  lua_setmetatable(L, -2);

  if (!mz_zip_reader_init_file(archive, path, flags)) {
    const char* msg = mz_zip_get_error_string(mz_zip_get_last_error(archive));
    lua_pushnil(L);
    lua_pushfstring(L, "read %s failed: %s", path, msg);
    return 2;
  }

  return 1;
}

static int lmz_reader_gc(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  mz_zip_reader_end(archive);
  return 0;
}

static int lmz_reader_get_num_files(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  lua_pushinteger(L, mz_zip_reader_get_num_files(archive));
  return 1;
}

static int lmz_reader_locate_file(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  const char *path = luaL_checkstring(L, 2);
  mz_uint32 flags = 0;
  if (lua_isinteger(L, 3)) {
    flags = lua_tointeger(L, 3);
  } else if (lua_istable(L, 3)) {
    lua_getfield(L, 3, "case_sensitive");
    if (lua_toboolean(L, -1))
      flags |= MZ_ZIP_FLAG_CASE_SENSITIVE;
    lua_pop(L, 1);

    lua_getfield(L, 3, "ignore_path");
    if (lua_toboolean(L, -1))
      flags |= MZ_ZIP_FLAG_IGNORE_PATH;
    lua_pop(L, 1);
  } else if (!lua_isnoneornil(L, 3)) {
    return luaL_argerror(L, 3, "expected integer or table");
  }

  int index = mz_zip_reader_locate_file(archive, path, NULL, flags);
  if (index < 0) {
    lua_pushnil(L);
    lua_pushstring(L, mz_zip_get_error_string(mz_zip_get_last_error(archive)));
    return 2;
  }

  lua_pushinteger(L, index + 1);
  return 1;
}

static int lmz_reader_stat(lua_State* L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  mz_zip_archive_file_stat stat;
  if (!mz_zip_reader_file_stat(archive, file_index, &stat)) {
    lua_pushnil(L);
    lua_pushstring(L, mz_zip_get_error_string(mz_zip_get_last_error(archive)));
    return 2;
  }

  lua_createtable(L, 0, 16);
  lua_pushinteger(L, file_index + 1);
  lua_setfield(L, -2, "index");
  lua_pushinteger(L, stat.m_version_made_by);
  lua_setfield(L, -2, "version_made_by");
  lua_pushinteger(L, stat.m_version_needed);
  lua_setfield(L, -2, "version_needed");
  lua_pushinteger(L, stat.m_bit_flag);
  lua_setfield(L, -2, "bit_flag");
  lua_pushinteger(L, stat.m_method);
  lua_setfield(L, -2, "method");
  lua_pushinteger(L, stat.m_time);
  lua_setfield(L, -2, "time");
  lua_pushinteger(L, stat.m_crc32);
  lua_setfield(L, -2, "crc32");
  lua_pushinteger(L, stat.m_comp_size);
  lua_setfield(L, -2, "comp_size");
  lua_pushinteger(L, stat.m_uncomp_size);
  lua_setfield(L, -2, "uncomp_size");
  lua_pushinteger(L, stat.m_internal_attr);
  lua_setfield(L, -2, "internal_attr");
  lua_pushinteger(L, stat.m_external_attr);
  lua_setfield(L, -2, "external_attr");
  lua_pushstring(L, stat.m_filename);
  lua_setfield(L, -2, "filename");
  lua_pushstring(L, stat.m_comment);
  lua_setfield(L, -2, "comment");
  lua_pushboolean(L, stat.m_is_directory);
  lua_setfield(L, -2, "is_directory");
  return 1;
}

static int lmz_reader_get_filename(lua_State* L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  char pFilename[0x1000];

  if (!mz_zip_reader_get_filename(archive, file_index, pFilename, sizeof(pFilename))) {
    lua_pushnil(L);
    lua_pushstring(L, mz_zip_get_error_string(mz_zip_get_last_error(archive)));
    return 2;
  }

  lua_pushstring(L, pFilename);
  return 1;
}

static int lmz_reader_is_file_a_directory(lua_State  *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;

  lua_pushboolean(L, mz_zip_reader_is_file_a_directory(archive, file_index));
  return 1;
}

static int lmz_reader_extract(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  mz_uint flags = luaL_optinteger(L, 3, 0);

  size_t out_len = 0;
  char* out_buf = mz_zip_reader_extract_to_heap(archive, file_index, &out_len, flags);
  if (!out_buf) {
    lua_pushnil(L);
    lua_pushstring(L, mz_zip_get_error_string(mz_zip_get_last_error(archive)));
    return 2;
  }

  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int lmz_reader_get_offset(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_reader");

  lua_pushinteger(L, mz_zip_get_archive_file_start_offset(archive));
  return 1;
}

static int lmz_writer_init(lua_State *L) {
  size_t initial_reserve_size = luaL_optinteger(L, 1, 0);
  size_t initial_allocation_size = luaL_optinteger(L, 2, 128 * 1024);

  mz_zip_archive* archive = lua_newuserdata(L, sizeof(*archive));
  memset(archive, 0, sizeof(*archive));

  luaL_getmetatable(L, "miniz_writer");
  lua_setmetatable(L, -2);

  if (!mz_zip_writer_init_heap(archive, initial_reserve_size, initial_allocation_size)) {
    return luaL_error(L, "failed to initialize writer: %s", mz_zip_get_error_string(mz_zip_get_last_error(archive)));
  }

  return 1;
}

static int lmz_writer_gc(lua_State *L) {
  mz_zip_archive* archive = luaL_checkudata(L, 1, "miniz_writer");
  mz_zip_writer_end(archive);
  return 0;
}

static int lmz_writer_add_from_zip_reader(lua_State *L) {
  mz_zip_archive* zip = luaL_checkudata(L, 1, "miniz_writer");
  mz_zip_archive* source = luaL_checkudata(L, 2, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 3) - 1;

  if (!mz_zip_writer_add_from_zip_reader(zip, source, file_index)) {
    return luaL_error(L, "failed to add: %s", mz_zip_get_error_string(mz_zip_get_last_error(zip)));
  }

  return 0;
}

static int lmz_writer_add(lua_State *L) {
  mz_zip_archive* zip = luaL_checkudata(L, 1, "miniz_writer");
  const char* path = luaL_checkstring(L, 2);
  size_t size = 0;
  const char* data = luaL_checklstring(L, 3, &size);
  mz_uint level_and_flags = luaL_optinteger(L, 4, 0);
  MZ_TIME_T mtime = luaL_optinteger(L, 5, 0);
  if (mtime == 0) 
    mtime = time(NULL);

  if (!mz_zip_writer_add_mem_ex_v2(zip, path, data, size, NULL, 0, level_and_flags, 0, 0, &mtime, NULL, 0, NULL, 0)) {
    return luaL_error(L, "failed to add: %s", mz_zip_get_error_string(mz_zip_get_last_error(zip)));
  }

  return 0;
}

static int lmz_writer_finalize(lua_State *L) {
  mz_zip_archive* zip = luaL_checkudata(L, 1, "miniz_writer");
  void* data;
  size_t size;

  if (!mz_zip_writer_finalize_heap_archive(zip, &data, &size)) {
    return luaL_error(L, "failed to finalize: %s", mz_zip_get_error_string(mz_zip_get_last_error(zip)));
  }

  lua_pushlstring(L, (const char*)data, size);
  zip->m_pFree(zip->m_pAlloc_opaque, data);
  return 1;
}

static int lmz_deflator_init(lua_State* L) {
  int level = lmz_check_compression_level(L, 1);

  mz_streamp stream = lua_newuserdata(L, sizeof(*stream));
  memset(stream, 0, sizeof(*stream));

  luaL_getmetatable(L, "miniz_deflator");
  lua_setmetatable(L, -2);

  int status = mz_deflateInit(stream, level);
  if (status != MZ_OK) {
    const char* msg = mz_error(status);
    if (!msg) {
      msg = "unknown error";
    }

    return luaL_error(L, "failed to initialize stream: %s", msg);
  }

  return 1;
}

static int lmz_inflator_init(lua_State* L) {
  mz_streamp stream = lua_newuserdata(L, sizeof(*stream));
  memset(stream, 0, sizeof(*stream));

  luaL_getmetatable(L, "miniz_inflator");
  lua_setmetatable(L, -2);

  int status = mz_inflateInit(stream);
  if (status != MZ_OK) {
    const char* msg = mz_error(status);
    if (!msg) {
      msg = "unknown error";
    }

    return luaL_error(L, "failed to initialize stream: %s", msg);
  }

  return 1;
}

static int lmz_deflator_gc(lua_State* L) {
  mz_streamp stream = luaL_checkudata(L, 1, "miniz_deflator");
  mz_deflateEnd(stream);
  return 0;
}

static int lmz_inflator_gc(lua_State* L) {
  mz_streamp stream = luaL_checkudata(L, 1, "miniz_inflator");
  mz_inflateEnd(stream);
  return 0;
}

static const char* flush_types[] = {
  "no", "partial", "sync", "full", "finish", "block",
  NULL
};

static int lmz_inflator_deflator_impl(lua_State* L, mz_streamp stream, int inflate) {
  size_t data_size;
  const char* data = luaL_checklstring(L, 2, &data_size);
  int flush = luaL_checkoption(L, 3, "no", flush_types);

  stream->avail_in = data_size;
  stream->next_in = (const unsigned char*)data;
  mz_ulong total_in_before = stream->total_in;

  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  do {
    stream->avail_out = LUAL_BUFFERSIZE;
    stream->next_out = (unsigned char*)luaL_prepbuffer(&buf);
    
    size_t before = stream->total_out;
    int status = inflate ? mz_inflate(stream, flush) : mz_deflate(stream, flush);
    size_t added = stream->total_out - before;
  
    switch (status) {
      case MZ_OK:
      case MZ_STREAM_END:
        luaL_addsize(&buf, added);
        break;
      case MZ_BUF_ERROR:
        break;
      default:
        lua_pushnil(L);
        lua_pushstring(L, mz_error(status));
        lua_pushinteger(L, stream->total_in - total_in_before);
        return 3;
    }
  } while (stream->avail_out == 0);
  luaL_pushresult(&buf);
  lua_pushnil(L);
  lua_pushinteger(L, stream->total_in - total_in_before);
  return 3;
}

static int lmz_deflator_deflate(lua_State* L) {
  mz_streamp stream = luaL_checkudata(L, 1, "miniz_deflator");
  return lmz_inflator_deflator_impl(L, stream, 0);
}

static int lmz_inflator_inflate(lua_State* L) {
  mz_streamp stream = luaL_checkudata(L, 1, "miniz_inflator");
  return lmz_inflator_deflator_impl(L, stream, 1);
}

static int lmz_inflate(lua_State* L) {
  size_t in_len = 0;
  const char* in_buf = luaL_checklstring(L, 1, &in_len);
  int flags = 0;
  if (lua_isinteger(L, 2)) {
    flags = lua_tointeger(L, 2);
  } else if (lua_istable(L, 2)) {
    lua_getfield(L, 2, "zlib");
    if (lua_toboolean(L, -1))
      flags |= TINFL_FLAG_PARSE_ZLIB_HEADER;
    lua_pop(L, 1);
  } else if (!lua_isnoneornil(L, 2)) {
    return luaL_argerror(L, 2, "expected table");
  }

  size_t out_len = 0;
  char* out_buf = tinfl_decompress_mem_to_heap(in_buf, in_len, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int lmz_deflate(lua_State* L) {
  size_t in_len = 0;
  const char* in_buf = luaL_checklstring(L, 1, &in_len);

  int flags = TDEFL_DEFAULT_MAX_PROBES;
  if (lua_isinteger(L, 2)) {
    flags = lua_tointeger(L, 2);
  } else if (lua_istable(L, 2)) {
    lua_getfield(L, 2, "probes");
    if (lua_isinteger(L, -1)) {
      int hash_probes = lua_tointeger(L, -1);
      if (hash_probes < 1 || hash_probes > 0xFFF) {
        return luaL_argerror(L, 2, "probes option must be between 1 and 4095");
      }
      flags &= ~TDEFL_MAX_PROBES_MASK;
      flags |= hash_probes;
    } else if (!lua_isnoneornil(L, -1)) {
      return luaL_argerror(L, 2, "probes option must be an integer");
    }
    lua_pop(L, 1);

    lua_getfield(L, 2, "zlib");
    if (lua_toboolean(L, -1)) 
      flags |= TDEFL_WRITE_ZLIB_HEADER;
    lua_pop(L, 1);

    lua_getfield(L, 2, "filter_matches");
    if (lua_toboolean(L, -1))
      flags |= TDEFL_FILTER_MATCHES;
    lua_pop(L, 1);

    lua_getfield(L, 2, "force_static");
    if (lua_toboolean(L, -1)) 
      flags |= TDEFL_FORCE_ALL_STATIC_BLOCKS;
    lua_pop(L, 1);

    lua_getfield(L, 2, "force_raw");
    if (lua_toboolean(L, -1)) 
      flags |= TDEFL_FORCE_ALL_RAW_BLOCKS;
    lua_pop(L, 1);
  } else if (!lua_isnoneornil(L, 2)) {
    return luaL_argerror(L, 2, "expected integer or table");
  }

  size_t out_len = 0;
  char* out_buf = tdefl_compress_mem_to_heap(in_buf, in_len, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int lmz_adler32(lua_State* L) {
  mz_ulong adler = luaL_optinteger(L, 1, MZ_ADLER32_INIT);
  size_t buf_len = 0;
  const unsigned char* ptr = (const unsigned char*)luaL_optlstring(L, 2, NULL, &buf_len);
  adler = mz_adler32(adler, ptr, buf_len);
  lua_pushinteger(L, adler);
  return 1;
}

static int lmz_crc32(lua_State* L) {
  mz_ulong crc32 = luaL_optinteger(L, 1, MZ_CRC32_INIT);
  size_t buf_len = 0;
  const unsigned char* ptr = (const unsigned char*)luaL_optlstring(L, 2, NULL, &buf_len);
  crc32 = mz_crc32(crc32, ptr, buf_len);
  lua_pushinteger(L, crc32);
  return 1;
}

static int lmz_version(lua_State* L) {
  lua_pushstring(L, mz_version());
  return 1;
}

static int lmz_compress(lua_State* L)
{
  size_t in_len = 0;
  const unsigned char *inb = (const unsigned char *)luaL_checklstring(L, 1, &in_len);

  int level = lmz_check_compression_level(L, 2);

  size_t out_len = mz_compressBound(in_len);
  unsigned char *outb = (unsigned char *)malloc(out_len);

  int ret = mz_compress2(outb, &out_len, inb, in_len, level);
  switch (ret) {
    case MZ_OK:
      lua_pushlstring(L, (const char*)outb, out_len);
      ret = 1;
      break;
    default:
      lua_pushnil(L);
      lua_pushstring(L, mz_error(ret));
      ret = 2;
      break;
  }
  free(outb);
  return ret;
}

static int lmz_uncompress(lua_State* L)
{
  size_t in_len = 0;
  const unsigned char* inb = (const unsigned char*)luaL_checklstring(L, 1, &in_len);
  mz_ulong out_len = luaL_optinteger(L, 2, in_len * 2);
  if (out_len < in_len)
    out_len = in_len;

  int ret;
  unsigned char* outb;
  mz_ulong processed;
  do {
    processed = in_len;
    outb = malloc(out_len);
    ret = mz_uncompress2(outb, &out_len, inb, &processed);
    if (ret == MZ_BUF_ERROR) {
      out_len *= 2;
      free(outb);
    } else {
      break;
    }
  } while (out_len > 1 && out_len < INT_MAX);

  switch (ret) {
    case MZ_OK:
      lua_pushlstring(L, (const char*)outb, out_len);
      lua_pushinteger(L, processed);
      ret = 2;
      break;
    default:
      lua_pushnil(L);
      lua_pushstring(L, mz_error(ret));
      ret = 2;
      break;
  }
  free(outb);
  return ret;
}

static const luaL_Reg lminiz_reader_m[] = {
  {"get_num_files", lmz_reader_get_num_files},
  {"stat", lmz_reader_stat},
  {"get_filename", lmz_reader_get_filename},
  {"is_directory", lmz_reader_is_file_a_directory},
  {"extract", lmz_reader_extract},
  {"locate_file", lmz_reader_locate_file},
  {"get_offset", lmz_reader_get_offset},
  {NULL, NULL}
};

static const luaL_Reg lminiz_writer_m[] = {
  {"add_from_zip", lmz_writer_add_from_zip_reader},
  {"add", lmz_writer_add},
  {"finalize", lmz_writer_finalize},
  {NULL, NULL}
};

static const luaL_Reg lminiz_deflator_m[] = {
  {"deflate", lmz_deflator_deflate},
  {NULL,NULL}
};

static const luaL_Reg lminiz_inflator_m[] = {
  {"inflate", lmz_inflator_inflate},
  {NULL,NULL}
};

static const luaL_Reg lminiz_f[] = {
  {"new_reader", lmz_reader_init},
  {"new_writer", lmz_writer_init},
  {"inflate", lmz_inflate},
  {"deflate", lmz_deflate},
  {"adler32", lmz_adler32},
  {"crc32", lmz_crc32},
  {"compress", lmz_compress},
  {"uncompress", lmz_uncompress},
  {"version", lmz_version},
  {"new_deflator", lmz_deflator_init},
  {"new_inflator", lmz_inflator_init},
  {NULL, NULL}
};

LUALIB_API int luaopen_miniz(lua_State *L) {
  luaL_newmetatable(L, "miniz_reader");
  luaL_newlib(L, lminiz_reader_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_reader_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);

  luaL_newmetatable(L, "miniz_writer");
  luaL_newlib(L, lminiz_writer_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_writer_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);

  luaL_newmetatable(L, "miniz_deflator");
  luaL_newlib(L, lminiz_deflator_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_deflator_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);

  luaL_newmetatable(L, "miniz_inflator");
  luaL_newlib(L, lminiz_inflator_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_inflator_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);

  luaL_newlib(L, lminiz_f);
  return 1;
}
