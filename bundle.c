// This is meant to be included from main.c, it's not standalone.
#include "miniz.c"

static char* bundle_root = NULL;


static void bundle_open_stat(lua_State *L, char* path, const char* name, uv_fs_t* req, uv_file* file) {
  uv_loop_t* loop = uv_default_loop();
  snprintf(path, 2*PATH_MAX, "%s/%s", bundle_root, name);
  *file = uv_fs_open(loop, req, path, O_RDONLY, 0644, NULL);
  uv_fs_req_cleanup(req);
  if (req->result == -1) {
    if (req->errorno == UV_ENOENT) {
      *file = 0;
      return;
    }
    uv_err_t err = uv_last_error(uv_default_loop());
    luaL_error(L, "Problem opening %s: %s", path, uv_strerror(err));
  }

  uv_fs_fstat(loop, req, *file, NULL);
  uv_fs_req_cleanup(req);
  if (req->result == -1) {
    uv_err_t err = uv_last_error(uv_default_loop());
    luaL_error(L, "Problem statting %s: %s", path, uv_strerror(err));
  }
}

static int bundle_stat(lua_State *L) {
  if (bundle_root) {
    char path[2*PATH_MAX];
    uv_fs_t req;
    uv_file file;
    bundle_open_stat(L, (char*)&path, luaL_checkstring(L, 1), &req, &file);
    if (file == 0) return 0;
    lua_createtable(L, 0, 3);
    lua_pushstring(L, S_ISDIR(req.statbuf.st_mode) ? "tree" :
                      S_ISREG(req.statbuf.st_mode) ? "file" :
                      S_ISLNK(req.statbuf.st_mode) ? "link" : "other");
    lua_setfield(L, -2, "type");
    lua_pushinteger(L, req.statbuf.st_size);
    lua_setfield(L, -2, "size");
    lua_pushinteger(L, req.statbuf.st_mtime);
    lua_setfield(L, -2, "mtime");
    return 1;
  }
  return 0;
}

static int bundle_readdir(lua_State *L) {
  if (bundle_root) {
    char path[2*PATH_MAX];
    uv_loop_t* loop = uv_default_loop();
    uv_fs_t req;
    uv_file file;
    bundle_open_stat(L, (char*)&path, luaL_checkstring(L, 1), &req, &file);
    if (file == 0) return 0;
    if (!S_ISDIR(req.statbuf.st_mode)) {
      return luaL_error(L, "Not a directory %s\n", path);
    }
    uv_fs_readdir(loop, &req, path, 0, NULL);
    if (req.result == -1) {
      uv_fs_req_cleanup(&req);
      uv_err_t err = uv_last_error(uv_default_loop());
      return luaL_error(L, "Problem reading %s: %s", path, uv_strerror(err));
    }
    int i;
    char* namebuf = (char*)req.ptr;
    int nnames = req.result;

    lua_createtable(L, nnames, 0);
    for (i = 0; i < nnames; ++i) {
      lua_pushstring(L, namebuf);
      lua_rawseti(L, -2, i + 1);
      namebuf += strlen(namebuf);
      assert(*namebuf == '\0');
      namebuf += 1;
    }
    uv_fs_req_cleanup(&req);

    return 1;
  }
  return 0;
}

static int bundle_readfile(lua_State *L) {
  if (bundle_root) {
    char path[2*PATH_MAX];
    uv_loop_t* loop = uv_default_loop();
    uv_fs_t req;
    uv_file file;
    bundle_open_stat(L, (char*)&path, luaL_checkstring(L, 1), &req, &file);
    if (file == 0) return 0;

    size_t length = req.statbuf.st_size;
    char* buf = malloc(length);
    uv_fs_read(loop, &req, file, buf, length, 0, NULL);
    uv_fs_req_cleanup(&req);
    if (req.result == -1) {
      uv_err_t err = uv_last_error(uv_default_loop());
      return luaL_error(L, "Problem reading %s: %s", path, uv_strerror(err));
    }

    lua_pushlstring(L, buf, req.result);
    free(buf);
    return 1;

  }
  else {

    return 0;
  }
}

static const luaL_Reg bundle_exports[] = {
  {"stat", bundle_stat},
  {"readdir", bundle_readdir},
  {"readfile", bundle_readfile},
  {NULL, NULL},
};

static int luaopen_bundle(lua_State *L) {
  bundle_root = getenv("LUVI_IN");
  size_t size = 2*PATH_MAX;
  char exec_path[2*PATH_MAX];

  if (!bundle_root) {
    if (uv_exepath(exec_path, &size)) {
      uv_err_t err = uv_last_error(uv_default_loop());
      return luaL_error(L, "uv_exepath: %s", uv_strerror(err));
    }
    printf("self %s\n", exec_path);
    luaL_error(L, "TODO: handle looking inside zip");
  }

  luaL_newlib(L, bundle_exports);
  return 1;
}
