#ifndef LTYPE_H
#define LTYPE_H

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

class LType {
public:
  LType() { refcount = 1; }
  virtual ~LType() = default;

  void ref() const { refcount++; }
  void unref() const { refcount--; if(!refcount) delete this; }

  virtual void wrap_unref(lua_State *L);
  virtual void wrap(lua_State *L);

  static void z_wrap(LType *v, lua_State *L) { if(v) v->wrap(L); else lua_pushnil(L); }
  static void z_wrap_unref(LType *v, lua_State *L) { if(v) v->wrap_unref(L); else lua_pushnil(L); }

  static int luaopen(lua_State *L);

protected:
  virtual const char *type_name() const = 0;
  mutable int refcount;
  static int l_gc(lua_State *L);
  static int l_index(lua_State *L);
  static void make_metatable(lua_State *L, const luaL_Reg *table, const char *tname);
  static void make_metatable_with_index(lua_State *L, const luaL_Reg *table, const char *tname, int (*index)(lua_State *));
  static LType *checkparam(lua_State *L, int idx, const char *tname);
  static LType *getparam(lua_State *L, int idx, const char *tname);

private:
  static int weak_table_ref;

  static int l_type(lua_State *L);
};

#endif
