#include "ltype.h"

#include <string.h>
#include <assert.h>
#include <stdlib.h>

int LType::weak_table_ref;

void LType::wrap_unref(lua_State *L)
{
  lua_rawgeti(L, LUA_REGISTRYINDEX, weak_table_ref);
  lua_pushlightuserdata(L, this);
  lua_rawget(L, -2);
  if(lua_isnil(L, -1)) {
    LType **p = static_cast<LType **>(lua_newuserdata(L, sizeof(LType *)));
    *p = this;
    luaL_getmetatable(L, type_name());
    lua_setmetatable(L, -2);
    lua_pushlightuserdata(L, this);
    lua_pushvalue(L, -2);
    lua_rawset(L, -5);
    lua_remove(L, -2);
    lua_remove(L, -2);
  } else {
    lua_remove(L, -2);
    unref();
  }
}

void LType::wrap(lua_State *L)
{
  ref();
  wrap_unref(L);
}

LType *LType::checkparam(lua_State *L, int idx, const char *tname)
{
  if(!lua_getmetatable(L, idx))
    return nullptr;

  lua_rawget(L, LUA_REGISTRYINDEX);
  const char *name = lua_tostring(L, -1);

  if(!name || strcmp(name, tname)) {
    lua_pop(L, 1);
    return nullptr;
  }
  lua_pop(L, 1);

  return *static_cast<LType **>(lua_touserdata(L, idx));
}

LType *LType::getparam(lua_State *L, int idx, const char *tname)
{
  LType *p = checkparam(L, idx, tname);
  if(!p) {
    char msg[256];
    sprintf(msg, "%s expected", tname);
    luaL_argcheck(L, p, idx, msg);
  }
  return p;
}

int LType::l_gc(lua_State *L)
{
  (*static_cast<LType **>(lua_touserdata(L, 1)))->unref();
  return 0;
}

int LType::l_index(lua_State *L)
{
  lua_getmetatable(L, 1);
  lua_pushvalue(L, 2);
  lua_rawget(L, -2);
  if(!lua_isnil(L, -1))
    return 1;
  lua_pop(L, 1);

  lua_getfield(L, -1, "__realindex");
  lua_insert(L, 1);
  lua_pop(L, 1);
  lua_call(L, 2, LUA_MULTRET);
  return lua_gettop(L);
}

void LType::make_metatable(lua_State *L, const luaL_Reg *table, const char *tname)
{
  luaL_newmetatable(L, tname);
  lua_pushvalue(L, -1);
  lua_pushstring(L, tname);
  lua_rawset(L, LUA_REGISTRYINDEX);
  lua_pushstring(L, "__index");
  lua_pushvalue(L, -2);
  lua_settable(L, -3);
  luaL_setfuncs(L, table, 0);
  lua_pop(L, 1);
}

void LType::make_metatable_with_index(lua_State *L, const luaL_Reg *table, const char *tname, int (*index)(lua_State *))
{
  luaL_newmetatable(L, tname);
  lua_pushvalue(L, -1);
  lua_pushstring(L, tname);
  lua_rawset(L, LUA_REGISTRYINDEX);
  lua_pushcfunction(L, l_index);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, index);
  lua_setfield(L, -2, "__realindex");
  luaL_setfuncs(L, table, 0);
  lua_pop(L, 1);
}

int LType::l_type(lua_State *L)
{
  int type = lua_type(L, 1);
  const char *name = lua_typename(L, type);
  if(type == LUA_TUSERDATA) {
    if(lua_getmetatable(L, 1)) {
      lua_rawget(L, LUA_REGISTRYINDEX);
      name = lua_tostring(L, -1);
      lua_pop(L, 1);
    }
  }
  lua_pushstring(L, name);
  return 1;
}

int LType::luaopen(lua_State *L)
{
  lua_newtable(L);
  lua_newtable(L);
  lua_pushstring(L, "v");
  lua_setfield(L, -2, "__mode");
  lua_setmetatable(L, -2);
  weak_table_ref = luaL_ref(L, LUA_REGISTRYINDEX);

  lua_register(L, "type", l_type);

  return 1;
}
