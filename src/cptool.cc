#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>

#include <iostream>

#include "parse.h"

static int l_parse(lua_State *L)
{
  std::string source(luaL_checkstring(L, 1));

  auto p = new Parse(std::move(source));
  p->wrap_unref(L);
  return 1;
}

static void do_scan(lua_State *L, std::string path, int &index)
{
  enum { F, D, U, O };

  DIR *d = opendir(path.c_str());
  if(!d)
    return;

  for(;;) {
    dirent *di = readdir(d);
    if(!di)
      break;
    if(di->d_name[0] == '.')
      continue;
    std::string fp = path + '/' + di->d_name;
    int type = di->d_type == DT_REG ? F : di->d_type == DT_DIR ? D : di->d_type == DT_UNKNOWN ? U : O;
    if(type == U) {
      struct stat st;
      if(lstat(fp.c_str(), &st) == 0) {
	type = S_ISREG(st.st_mode) ? F : S_ISDIR(st.st_mode) ? D : O;
      } else
	type = O;
    }
    if(type == F) {
      lua_pushlstring(L, fp.data(), fp.size());
      lua_rawseti(L, -2, index++);
    } else if(type == D)
      do_scan(L, fp, index);
  }
  closedir(d);
}

static int l_scan(lua_State *L)
{
  int count = lua_gettop(L);
  lua_newtable(L);
  int index = 1;
  for(int i=1; i<=count; i++) {
    std::string root(luaL_checkstring(L, i));
    do_scan(L, root, index);
  }
  return 1;
}

static int luaopen_cp(lua_State *L)
{
  static const luaL_Reg lib[] = {
    { "parse", l_parse },
    { "scan", l_scan },
    { }
  };

  luaL_newlib(L, lib);
  return 1;
}

static const luaL_Reg lualibs[] = {
  { "",              luaopen_base        },
  { LUA_LOADLIBNAME, luaopen_package     },
  { LUA_TABLIBNAME,  luaopen_table       },
  { LUA_IOLIBNAME,   luaopen_io          },
  { LUA_OSLIBNAME,   luaopen_os          },
  { LUA_STRLIBNAME,  luaopen_string      },
  { LUA_MATHLIBNAME, luaopen_math        },
  { LUA_DBLIBNAME,   luaopen_debug       },
  { LUA_COLIBNAME,   luaopen_coroutine   },
  { LUA_BITLIBNAME,  luaopen_bit32       },
  { "ltype",         LType::luaopen      },
  { "parse",         Parse::luaopen      },
  { "cp",            luaopen_cp          },
  { }
};


int main(int argc, char **argv)
{
  if(argc < 2) {
    std::cerr << "Usage:\n" << argv[0] << " file.lua [opts]\n";
    exit(1);
  }

  lua_State *L = luaL_newstate();
  for(const luaL_Reg *lib = lualibs; lib->func; lib++) {
    luaL_requiref(L, lib->name, lib->func, 1);
    lua_pop(L, 1);
  }

  lua_newtable(L);
  for(int i = 2; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i-1);
  }
  lua_setglobal(L, "arg");

  if(luaL_loadfile(L, argv[1])) {
    fprintf(stderr, "Error loading %s: %s\n", argv[1], lua_tostring(L, -1));
    exit(1);
  }

  if(lua_pcall(L, 0, 0, 0)) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
    exit(1);
  }

  lua_close(L);

  return 0;
}
