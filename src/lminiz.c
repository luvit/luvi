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

#include "./luvi.h"
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "../deps/miniz.c"

typedef struct {
  mz_zip_archive archive;
  uv_loop_t *loop;
  uv_fs_t req;
  uv_file fd;
} lmz_file_t;

typedef struct {
  int mode; // 0 = deflate, 1 = inflate
  mz_stream stream;
} lmz_stream_t;

static size_t lmz_file_read(void *pOpaque, mz_uint64 file_ofs, void *pBuf, size_t n) {
  lmz_file_t* zip = pOpaque;
  const uv_buf_t buf = uv_buf_init(pBuf, n);
  file_ofs += zip->archive.m_pState->m_file_archive_start_ofs;
  uv_fs_read(zip->loop, &(zip->req), zip->fd, &buf, 1, file_ofs, NULL);
  return zip->req.result;
}

static int lmz_check_compression_level(lua_State* L, int index) {
  int level = luaL_optint(L, index, MZ_DEFAULT_COMPRESSION);
  if (level < MZ_DEFAULT_COMPRESSION || level > MZ_BEST_COMPRESSION) {
    luaL_error(L, "Compression level must be between %d and %d", MZ_DEFAULT_COMPRESSION, MZ_BEST_COMPRESSION);
  }
  return level;
}

static int lmz_reader_init(lua_State* L) {
  const char* path = luaL_checkstring(L, 1);
  mz_uint32 flags = luaL_optint(L, 2, 0);
  mz_uint64 size;
  lmz_file_t* zip = lua_newuserdata(L, sizeof(*zip));
  mz_zip_archive* archive = &(zip->archive);
  luaL_getmetatable(L, "miniz_reader");
  lua_setmetatable(L, -2);
  memset(archive, 0, sizeof(*archive));
  zip->loop = uv_default_loop();
  zip->fd = uv_fs_open(zip->loop, &(zip->req), path, O_RDONLY, 0644, NULL);
  uv_fs_fstat(zip->loop, &(zip->req), zip->fd, NULL);
  size = zip->req.statbuf.st_size;
  archive->m_pRead = lmz_file_read;
  archive->m_pIO_opaque = zip;
  if (!mz_zip_reader_init(archive, size, flags)) {
    lua_pushnil(L);
    lua_pushfstring(L, "read %s fail because of %s", path,
      mz_zip_get_error_string(mz_zip_get_last_error(archive)));
    return 2;
  }
  return 1;
}

static int lmz_reader_gc(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  uv_fs_close(zip->loop, &(zip->req), zip->fd, NULL);
  uv_fs_req_cleanup(&(zip->req));
  mz_zip_reader_end(&(zip->archive));
  return 0;
}

static int lmz_writer_gc(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_writer");
  mz_zip_writer_end(&(zip->archive));
  return 0;
}

static int lmz_reader_get_num_files(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  lua_pushinteger(L, mz_zip_reader_get_num_files(&(zip->archive)));
  return 1;
}

static int lmz_reader_locate_file(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  const char *path = luaL_checkstring(L, 2);
  mz_uint32 flags = luaL_optint(L, 3, 0);
  int index = mz_zip_reader_locate_file(&(zip->archive), path, NULL, flags);
  if (index < 0) {
    lua_pushnil(L);
    lua_pushfstring(L, "Can't find file %s.", path);
    return 2;
  }
  lua_pushinteger(L, index + 1);
  return 1;
}

static int lmz_reader_stat(lua_State* L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  mz_zip_archive_file_stat stat;
  if (!mz_zip_reader_file_stat(&(zip->archive), file_index, &stat)) {
    lua_pushnil(L);
    lua_pushfstring(L, "%d is an invalid index", file_index);
    return 2;
  }
  lua_newtable(L);
  lua_pushinteger(L, file_index);
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
  return 1;
}

static int lmz_reader_get_filename(lua_State* L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  char pFilename[PATH_MAX];
  mz_uint filename_buf_size = PATH_MAX;
  if (!mz_zip_reader_get_filename(&(zip->archive), file_index, pFilename, filename_buf_size)) {
    lua_pushnil(L);
    lua_pushfstring(L, "%d is an invalid index", file_index);
    return 2;
  }
  lua_pushstring(L, pFilename);
  return 1;
}

static int lmz_reader_is_file_a_directory(lua_State  *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  lua_pushboolean(L, mz_zip_reader_is_file_a_directory(&(zip->archive), file_index));
  return 1;
}

static int lmz_reader_extract(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 2) - 1;
  mz_uint flags = luaL_optint(L, 3, 0);
  size_t out_len;
  char* out_buf = mz_zip_reader_extract_to_heap(&(zip->archive), file_index, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int lmz_reader_get_offset(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_zip_archive* archive = &(zip->archive);
  lua_pushinteger(L, archive->m_pState->m_file_archive_start_ofs);
  return 1;
}

static int lmz_writer_init(lua_State *L) {
  size_t size_to_reserve_at_beginning = luaL_optint(L, 1, 0);
  size_t initial_allocation_size = luaL_optint(L, 2, 128 * 1024);
  lmz_file_t* zip = lua_newuserdata(L, sizeof(*zip));
  mz_zip_archive* archive = &(zip->archive);
  luaL_getmetatable(L, "miniz_writer");
  lua_setmetatable(L, -2);
  memset(archive, 0, sizeof(*archive));
  zip->loop = uv_default_loop();
  if (!mz_zip_writer_init_heap(archive, size_to_reserve_at_beginning, initial_allocation_size)) {
    return luaL_error(L, "Problem initializing heap writer");
  }
  return 1;
}

static int lmz_writer_add_from_zip_reader(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_writer");
  lmz_file_t* source = luaL_checkudata(L, 2, "miniz_reader");
  mz_uint file_index = (mz_uint)luaL_checkinteger(L, 3) - 1;
  if (!mz_zip_writer_add_from_zip_reader(&(zip->archive), &(source->archive), file_index)) {
    return luaL_error(L, "Failure to copy file between zips");
  }
  return 0;
}

static int lmz_writer_add_mem(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_writer");
  const char* path = luaL_checkstring(L, 2);
  size_t size;
  const char* data = luaL_checklstring(L, 3, &size);
  mz_uint flags = luaL_optint(L, 4, 0);
  if (!mz_zip_writer_add_mem(&(zip->archive), path, data, size, flags)) {
    return luaL_error(L, "Failure to add entry to zip");
  }
  return 0;
}
static int lmz_writer_finalize(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_writer");
  void* data;
  size_t size;
  if (!mz_zip_writer_finalize_heap_archive(&(zip->archive), &data, &size)) {
    luaL_error(L, "Problem finalizing archive");
  }
  lua_pushlstring(L, data, size);
  return 1;
}

static int lmz_deflator_init(lua_State* L) {
  int level = lmz_check_compression_level(L, 1);
  lmz_stream_t* stream = lua_newuserdata(L, sizeof(*stream));
  mz_streamp miniz_stream = &(stream->stream);
  luaL_getmetatable(L, "miniz_deflator");
  lua_setmetatable(L, -2);
  memset(miniz_stream, 0, sizeof(*miniz_stream));
  int status = mz_deflateInit(miniz_stream, level);
  if (status != MZ_OK) {
    const char* msg = mz_error(status);
    if (msg) {
      luaL_error(L, "Problem initializing stream: %s", msg);
    } else {
      luaL_error(L, "Problem initializing stream");
    }
  }
  stream->mode = 0;
  return 1;
}

static int lmz_inflator_init(lua_State* L) {
  lmz_stream_t* stream = lua_newuserdata(L, sizeof(*stream));
  mz_streamp miniz_stream = &(stream->stream);
  luaL_getmetatable(L, "miniz_inflator");
  lua_setmetatable(L, -2);
  memset(miniz_stream, 0, sizeof(*miniz_stream));
  int status = mz_inflateInit(miniz_stream);
  if (status != MZ_OK) {
    const char* msg = mz_error(status);
    if (msg) {
      luaL_error(L, "Problem initializing stream: %s", msg);
    } else {
      luaL_error(L, "Problem initializing stream");
    }
  }
  stream->mode = 1;
  return 1;
}

static int lmz_deflator_gc(lua_State* L) {
  lmz_stream_t* stream = luaL_checkudata(L, 1, "miniz_deflator");
  mz_deflateEnd(&(stream->stream));
  return 0;
}

static int lmz_inflator_gc(lua_State* L) {
  lmz_stream_t* stream = luaL_checkudata(L, 1, "miniz_inflator");
  mz_inflateEnd(&(stream->stream));
  return 0;
}

static const char* flush_types[] = {
  "no", "partial", "sync", "full", "finish", "block",
  NULL
};

static int lmz_inflator_deflator_impl(lua_State* L, lmz_stream_t* stream) {
  mz_streamp miniz_stream = &(stream->stream);
  size_t data_size;
  const char* data = luaL_checklstring(L, 2, &data_size);
  int flush = luaL_checkoption(L, 3, "no", flush_types);
  miniz_stream->avail_in = data_size;
  miniz_stream->next_in = (const unsigned char*)data;
  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  do {
    miniz_stream->avail_out = LUAL_BUFFERSIZE;
    miniz_stream->next_out = (unsigned char*)luaL_prepbuffer(&buf);
    int status;
    size_t before = miniz_stream->total_out;
    if (stream->mode) {
      status = mz_inflate(miniz_stream, flush);
    } else {
      status = mz_deflate(miniz_stream, flush);
    }
    size_t added = miniz_stream->total_out - before;
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
        luaL_pushresult(&buf);
        return 3;
    }
  } while (miniz_stream->avail_out == 0);
  luaL_pushresult(&buf);
  return 1;
}

static int lmz_deflator_deflate(lua_State* L) {
  lmz_stream_t* stream = luaL_checkudata(L, 1, "miniz_deflator");
  return lmz_inflator_deflator_impl(L, stream);
}
static int lmz_inflator_inflate(lua_State* L) {
  lmz_stream_t* stream = luaL_checkudata(L, 1, "miniz_inflator");
  return lmz_inflator_deflator_impl(L, stream);
}

static int ltinfl(lua_State* L) {
  size_t in_len;
  const char* in_buf = luaL_checklstring(L, 1, &in_len);
  size_t out_len;
  int flags = luaL_optint(L, 2, 0);
  char* out_buf = tinfl_decompress_mem_to_heap(in_buf, in_len, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int ltdefl(lua_State* L) {
  size_t in_len;
  const char* in_buf = luaL_checklstring(L, 1, &in_len);
  size_t out_len;
  int flags = luaL_optint(L, 2, 0);
  char* out_buf = tdefl_compress_mem_to_heap(in_buf, in_len, &out_len, flags);
  lua_pushlstring(L, out_buf, out_len);
  free(out_buf);
  return 1;
}

static int lmz_adler32(lua_State* L) {
  mz_ulong adler = luaL_optint(L, 1, 0);
  size_t buf_len = 0;
  const unsigned char* ptr = (const unsigned char*)luaL_optlstring(L, 2, NULL, &buf_len);
  adler = mz_adler32(adler, ptr, buf_len);
  lua_pushinteger(L, adler);
  return 1;
}

static int lmz_crc32(lua_State* L) {
  mz_ulong crc32 = luaL_optint(L, 1, 0);
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
  int level, ret;
  size_t in_len, out_len;
  const unsigned char *inb;
  unsigned char *outb;
  in_len = 0;
  inb = (const unsigned char *)luaL_checklstring(L, 1, &in_len);
  level = lmz_check_compression_level(L, 2);
  out_len = mz_compressBound(in_len);
  outb = malloc(out_len);
  ret = mz_compress2(outb, &out_len, inb, in_len, level);
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
  int ret;
  size_t in_len, out_len;
  const unsigned char* inb;
  unsigned char* outb;
  in_len = 0;
  inb = (const unsigned char*)luaL_checklstring(L, 1, &in_len);
  out_len = luaL_optint(L, 2, in_len * 2);
  if (out_len < 1 || out_len > INT_MAX) {
    luaL_error(L, "Initial buffer size must be between 1 and %d", INT_MAX);
  }
  do {
    outb = malloc(out_len);
    ret = mz_uncompress(outb, &out_len, inb, in_len);
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

static const luaL_Reg lminiz_read_m[] = {
  {"get_num_files", lmz_reader_get_num_files},
  {"stat", lmz_reader_stat},
  {"get_filename", lmz_reader_get_filename},
  {"is_directory", lmz_reader_is_file_a_directory},
  {"extract", lmz_reader_extract},
  {"locate_file", lmz_reader_locate_file},
  {"get_offset", lmz_reader_get_offset},
  {NULL, NULL}
};

static const luaL_Reg lminiz_write_m[] = {
  {"add_from_zip", lmz_writer_add_from_zip_reader},
  {"add", lmz_writer_add_mem},
  {"finalize", lmz_writer_finalize},
  {NULL, NULL}
};

static const luaL_Reg lminiz_deflate_m[] = {
  {"deflate", lmz_deflator_deflate},
  {NULL,NULL}
};

static const luaL_Reg lminiz_inflate_m[] = {
  {"inflate", lmz_inflator_inflate},
  {NULL,NULL}
};

static const luaL_Reg lminiz_f[] = {
  {"new_reader", lmz_reader_init},
  {"new_writer", lmz_writer_init},
  {"inflate", ltinfl},
  {"deflate", ltdefl},
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
  luaL_newlib(L, lminiz_read_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_reader_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  luaL_newmetatable(L, "miniz_writer");
  luaL_newlib(L, lminiz_write_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_writer_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  luaL_newmetatable(L, "miniz_deflator");
  luaL_newlib(L, lminiz_deflate_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_deflator_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  luaL_newmetatable(L, "miniz_inflator");
  luaL_newlib(L, lminiz_inflate_m);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, lmz_inflator_gc);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  luaL_newlib(L, lminiz_f);
  return 1;
}
