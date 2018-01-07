#ifndef PARSE_H
#define PARSE_H

#include "ltype.h"

#include <vector>
#include <string>

class Token : public LType {
public:
  Token(std::string ws, std::string token, int line, int col);

  static int luaopen(lua_State *L);
  virtual const char *type_name() const;
  static Token *checkparam(lua_State *L, int idx);
  static Token *getparam(lua_State *L, int idx);

  void set_t(std::string s) { t_token = s; }
  void set_ws(std::string s) { t_ws = s; }

  void set_index(int index);
  std::string token() const { return t_token; }
  std::string ws() const { return t_ws; }
  std::string txt() const { return t_ws + t_token; }

private:
  static const char *type_name_s;

  std::string t_ws;
  std::string t_token;
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
  int replace(int start, int end, std::string source);
  int insert_line_before(int pos, std::string source);
  std::string str() const;

  int track_nl_bw(int pos) const;

  inline bool is_ws(char c) const;
  inline bool is_bin(char c) const;
  inline bool is_oct(char c) const;
  inline bool is_dec(char c) const;
  inline bool is_hex(char c) const;
  inline void step(std::string::const_iterator &p, int &line, int &col) const;

  void do_parse(std::string source, std::vector<Token *> &toks);

  static int l_len(lua_State *L);
  static int l_index(lua_State *L);
  static int l_replace(lua_State *L);
  static int l_insert_line_before(lua_State *L);
  static int l_str(lua_State *L);
};

#endif
