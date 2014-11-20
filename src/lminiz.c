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
#include "../deps/miniz.c"

typedef struct {
  mz_zip_archive archive;
  uv_loop_t *loop;
  uv_fs_t req;
  uv_file fd;
} lmz_file_t;

static size_t lmz_file_read(void *pOpaque, mz_uint64 file_ofs, void *pBuf, size_t n) {
  lmz_file_t* zip = pOpaque;
  const uv_buf_t buf = uv_buf_init(pBuf, n);
  uv_fs_read(zip->loop, &(zip->req), zip->fd, &buf, 1, file_ofs, NULL);
  return zip->req.result;
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
    lua_pushfstring(L, "%s does not appear to be a zip file", path);
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
  mz_uint file_index = luaL_checkinteger(L, 2) - 1;
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
  mz_uint file_index = luaL_checkinteger(L, 2) - 1;
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
  mz_uint file_index = luaL_checkinteger(L, 2) - 1;
  lua_pushboolean(L, mz_zip_reader_is_file_a_directory(&(zip->archive), file_index));
  return 1;
}

static int lmz_reader_extract(lua_State *L) {
  lmz_file_t* zip = luaL_checkudata(L, 1, "miniz_reader");
  mz_uint file_index = luaL_checkinteger(L, 2) - 1;
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
  lua_pushinteger(L, archive->m_start_ofs);
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
  mz_uint file_index = luaL_checkinteger(L, 3) - 1;
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

static const luaL_Reg lminiz_f[] = {
  {"new_reader", lmz_reader_init},
  {"new_writer", lmz_writer_init},
  {"inflate", ltinfl},
  {"deflate", ltdefl},
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
  luaL_newlib(L, lminiz_f);
  return 1;
}
