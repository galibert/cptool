#ifndef PARSE_H
#define PARSE_H

#include "ltype.h"

#include <vector>
#include <string>

class Token : public LType {
public:
  Token(std::string ws, std::string token, int line, int col, int index);

  static int luaopen(lua_State *L);
  virtual const char *type_name() const;
  static Token *checkparam(lua_State *L, int idx);
  static Token *getparam(lua_State *L, int idx);

  void set_index(int index);
  std::string t() const { return token; }

private:
  static const char *type_name_s;

  std::string ws;
  std::string token;
  int line;
  int col;
  int index;

  static int l_index(lua_State *L);
};

class Parse : public LType {
public:
  Parse(std::string source);
  virtual ~Parse();

  static int luaopen(lua_State *L);
  virtual const char *type_name() const;
  static Parse *checkparam(lua_State *L, int idx);
  static Parse *getparam(lua_State *L, int idx);

private:
  static const char *type_name_s;

  std::vector<Token *> tokens;

  bool prefix(std::string::const_iterator &p, std::string::const_iterator e, int &line, int &col, const char *pref) const;
  bool prefixp(std::string::const_iterator p, std::string::const_iterator e, const char *pref) const;
  inline bool is_ws(char c) const;
  inline bool is_bin(char c) const;
  inline bool is_oct(char c) const;
  inline bool is_dec(char c) const;
  inline bool is_hex(char c) const;
  inline void step(std::string::const_iterator &p, int &line, int &col) const;

  static int l_len(lua_State *L);
  static int l_index(lua_State *L);
};

#endif
