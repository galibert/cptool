#include "parse.h"

#include <iostream>

const char *Token::type_name_s = "token";
const char *Parse::type_name_s = "parse";

const char *Token::type_name() const
{
  return type_name_s;
}

Token *Token::checkparam(lua_State *L, int idx)
{
  return static_cast<Token *>(LType::checkparam(L, idx, type_name_s));
}

Token *Token::getparam(lua_State *L, int idx)
{
  return static_cast<Token *>(LType::getparam(L, idx, type_name_s));
}

const char *Parse::type_name() const
{
  return type_name_s;
}

Parse *Parse::checkparam(lua_State *L, int idx)
{
  return static_cast<Parse *>(LType::checkparam(L, idx, type_name_s));
}

Parse *Parse::getparam(lua_State *L, int idx)
{
  return static_cast<Parse *>(LType::getparam(L, idx, type_name_s));
}

int Token::luaopen(lua_State *L)
{
  static const luaL_Reg m[] = {
    { "__gc",  l_gc },
    { }
  };
  
  make_metatable_with_index(L, m, type_name_s, l_index);
  return 1;
}

int Parse::luaopen(lua_State *L)
{
  static const luaL_Reg m[] = {
    { "__gc",  l_gc  },
    { "__len", l_len },
    { }
  };
  
  Token::luaopen(L);
  make_metatable_with_index(L, m, type_name_s, l_index);
  return 1;
}

Parse::~Parse()
{
  for(Token *l : tokens) {
    l->set_index(-1);
    l->unref();
  }
}

int Parse::l_len(lua_State *L)
{
  Parse *p = getparam(L, 1);
  lua_pushinteger(L, p->tokens.size());
  return 1;
}

int Parse::l_index(lua_State *L)
{
  Parse *p = getparam(L, 1);

  int id = int(lua_tonumber(L, 2));
  if(id < 1 || id > int(p->tokens.size())) {
    lua_pushnil(L);
    return 1;
  }
  p->tokens[id-1]->wrap(L);
  return 1;
}

Token::Token(std::string _ws, std::string _token, int _line, int _col, int _index) :
  ws(_ws), token(_token), line(_line), col(_col), index(_index)
{
}

void Token::set_index(int _index)
{
  index = _index;
}

int Token::l_index(lua_State *L)
{
  Token *t = getparam(L, 1);
  if(!lua_isstring(L, 2))
    return 0;
  std::string field = lua_tostring(L, 2);
  if(field == "ws") {
    lua_pushlstring(L, t->ws.data(), t->ws.size());
    return 1;
  }
  if(field == "token") {
    lua_pushlstring(L, t->token.data(), t->token.size());
    return 1;
  }
  if(field == "line") {
    lua_pushinteger(L, t->line);
    return 1;
  }
  if(field == "col") {
    lua_pushinteger(L, t->col);
    return 1;
  }
  if(field == "index") {
    lua_pushinteger(L, t->index);
    return 1;
  }
  return 0;
}

bool Parse::prefix(std::string::const_iterator &p, std::string::const_iterator e, int &line, int &col, const char *pref) const
{
  auto p1 = p;
  int line1 = line;
  int col1 = col;
  while(p1 != e && *pref) {
    if(*p1 != *pref)
      return false;
    step(p1, line1, col1);
    pref++;
  }
  p = p1;
  line = line1;
  col = col1;
  return true;
}

bool Parse::prefixp(std::string::const_iterator p, std::string::const_iterator e, const char *pref) const
{
  while(p != e && *pref) {
    if(*p != *pref)
      return false;
    p++;
    pref++;
  }
  return true;
}

bool Parse::is_ws(char c) const
{
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

bool Parse::is_bin(char c) const
{
  return c >= '0' && c <= '1';
}

bool Parse::is_oct(char c) const
{
  return c >= '0' && c <= '7';
}

bool Parse::is_dec(char c) const
{
  return c >= '0' && c <= '9';
}

bool Parse::is_hex(char c) const
{
  return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

void Parse::step(std::string::const_iterator &p, int &line, int &col) const
{
  if(*p++ == '\n') {
    line++;
    col = 0;
  } else
    col++;
}

Parse::Parse(std::string source)
{
  auto p = source.cbegin();
  auto e = source.cend();
  int line = 1;
  int col = 0;
  while(p != e) {
    auto q = p;
    while(p != e && is_ws(*p))
      step(p, line, col);
    std::string ws(q, p);
    int l = line;
    int c = col;
    q = p; 

    if(p != e) {

      // Comments
      if(prefix(p, e, line, col, "//")) {
	while(p != e && l == line)
	  step(p, line, col);
	goto token_done;
      }

      if(prefix(p, e, line, col, "/*")) {
	while(p != e && !prefix(p, e, line, col, "*/"))
	  step(p, line, col);
	goto token_done;
      }

      // <> includes
      if(*p == '<') {
	if(tokens.size() >= 2 && tokens.end()[-1]->t() == "include" && (tokens.end()[-2]->t() == "#" || tokens.end()[-2]->t() == "%:")) {
	  while(p != e && *p != '>' && *p != '\n')
	    step(p, line, col);
	  if(p != e && *p == '>')
	    step(p, line, col);
	  goto token_done;
	}
      }

      // Operators
      if(prefix(p, e, line, col, "%:%:") ||
	 prefix(p, e, line, col, "->*") ||
	 prefix(p, e, line, col, "...") ||
	 prefix(p, e, line, col, "<<=") ||
	 prefix(p, e, line, col, ">>=") ||
	 prefix(p, e, line, col, "!=") ||
	 prefix(p, e, line, col, "##") ||
	 prefix(p, e, line, col, "%:") ||
	 prefix(p, e, line, col, "%=") ||
	 prefix(p, e, line, col, "%>") ||
	 prefix(p, e, line, col, "&&") ||
	 prefix(p, e, line, col, "&=") ||
	 prefix(p, e, line, col, "*=") ||
	 prefix(p, e, line, col, "++") ||
	 prefix(p, e, line, col, "+=") ||
	 prefix(p, e, line, col, "--") ||
	 prefix(p, e, line, col, "-=") ||
	 prefix(p, e, line, col, "->") ||
	 prefix(p, e, line, col, ".*") ||
	 prefix(p, e, line, col, "/=") ||
	 prefix(p, e, line, col, "::") ||
	 prefix(p, e, line, col, ":>") ||
	 prefix(p, e, line, col, "<%") ||
	 ((!prefixp(p, e, "<::")) && prefix(p, e, line, col, "<:")) ||
	 prefix(p, e, line, col, "<<") ||
	 prefix(p, e, line, col, "<=") ||
	 prefix(p, e, line, col, "==") ||
	 prefix(p, e, line, col, ">=") ||
	 prefix(p, e, line, col, ">>") ||
	 prefix(p, e, line, col, "^=") ||
	 prefix(p, e, line, col, "|=") ||
	 prefix(p, e, line, col, "||") ||
	 prefix(p, e, line, col, "!") ||
	 prefix(p, e, line, col, "#") ||
	 prefix(p, e, line, col, "%") ||
	 prefix(p, e, line, col, "&") ||
	 prefix(p, e, line, col, "(") ||
	 prefix(p, e, line, col, ")") ||
	 prefix(p, e, line, col, "*") ||
	 prefix(p, e, line, col, "+") ||
	 prefix(p, e, line, col, ",") ||
	 prefix(p, e, line, col, "-") ||
//	 prefix(p, e, line, col, ".") ||  // Don't do it here or we'll miss some of the decimal floating point numbers
	 prefix(p, e, line, col, "/") ||
	 prefix(p, e, line, col, ":") ||
	 prefix(p, e, line, col, ";") ||
	 prefix(p, e, line, col, "<") ||
	 prefix(p, e, line, col, "=") ||
	 prefix(p, e, line, col, ">") ||
	 prefix(p, e, line, col, "?") ||
	 prefix(p, e, line, col, "[") ||
	 prefix(p, e, line, col, "]") ||
	 prefix(p, e, line, col, "^") ||
	 prefix(p, e, line, col, "{") ||
	 prefix(p, e, line, col, "|") ||
	 prefix(p, e, line, col, "}") ||
	 prefix(p, e, line, col, "~"))
	goto token_done;

      // Strings (not raw strings, can't be bothered)
      if(prefix(p, e, line, col, "\"") ||
	 prefix(p, e, line, col, "u8\"") ||
	 prefix(p, e, line, col, "u\"") ||
	 prefix(p, e, line, col, "U\"") ||
	 prefix(p, e, line, col, "L\"")) {
	while(p != e) {
	  char c = *p;
	  step(p, line, col);

	  if(c == '\\') {
	    if(p != e)
	      step(p, line, col);
	  } else if(c == '"')
	    break;
	}
	goto token_done;
      }

      // Characters
      if(prefix(p, e, line, col, "'") ||
	 prefix(p, e, line, col, "u8'") ||
	 prefix(p, e, line, col, "u'") ||
	 prefix(p, e, line, col, "U'") ||
	 prefix(p, e, line, col, "L'")) {
	while(p != e) {
	  char c = *p;
	  step(p, line, col);

	  if(c == '\\') {
	    if(p != e)
	      step(p, line, col);
	  } else if(c == '\'')
	    break;
	}
	goto token_done;
      }

      // Identifiers
      if((*p >= 'A' && *p <= 'Z') || (*p >= 'a' && *p <= 'z') || *p == '_') {
	do
	  step(p, line, col);
	while(p != e && ((*p >= 'A' && *p <= 'Z') || (*p >= 'a' && *p <= 'z') || (*p >= '0' && *p <= '9') || *p == '_'));
	goto token_done;
      }

      // Numbers
      if(is_dec(*p)) {
	bool hexp = prefix(p, e, line, col, "0x") || prefix(p, e, line, col, "0X");
	bool binp = !hexp && (prefix(p, e, line, col, "0b") || prefix(p, e, line, col, "0B"));
	bool octp = (!prefixp(p, e, "0.")) && prefix(p, e, line, col, "0");

	if(binp) {
	  if(p != e && is_bin(*p)) {
	    step(p, line, col);
	    while(p != e) {
	      if(*p == '\'' && p+1 != e && is_bin(p[1])) {
		step(p, line, col);
		step(p, line, col);
	      } else if(is_bin(*p))
		step(p, line, col);
	      else
		break;
	    }
	  }
	  bool u1 = prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  prefix(p, e, line, col, "ll") || prefix(p, e, line, col, "LL") || prefix(p, e, line, col, "l") || prefix(p, e, line, col, "L");
	  if(!u1)
	    prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  goto token_done;
	}

	if(octp) {
	  if(p != e && is_oct(*p)) {
	    step(p, line, col);
	    while(p != e) {
	      if(*p == '\'' && p+1 != e && is_oct(p[1])) {
		step(p, line, col);
		step(p, line, col);
	      } else if(is_oct(*p))
		step(p, line, col);
	      else
		break;
	    }
	  }
	  bool u1 = prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  prefix(p, e, line, col, "ll") || prefix(p, e, line, col, "LL") || prefix(p, e, line, col, "l") || prefix(p, e, line, col, "L");
	  if(!u1)
	    prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  goto token_done;
	}

	if(hexp) {
	  if(p != e && is_hex(*p)) {
	    step(p, line, col);
	    while(p != e) {
	      if(*p == '\'' && p+1 != e && is_hex(p[1])) {
		step(p, line, col);
		step(p, line, col);
	      } else if(is_hex(*p))
		step(p, line, col);
	      else
		break;
	    }
	    if(p != e && (*p == '.' || (*p == 'p' || *p == 'P'))) {
	      // Floating point, no suffixes
	      if(*p == '.') {
		step(p, line, col);
		if(p == e || !is_hex(*p))
		  goto token_done;
		step(p, line, col);
		while(p != e) {
		  if(*p == '\'' && p+1 != e && is_hex(p[1])) {
		    step(p, line, col);
		    step(p, line, col);
		  } else if(is_hex(*p))
		    step(p, line, col);
		  else
		    break;
		}
		if(p == e || (*p != 'p' && *p != 'P'))
		  goto token_done;
	      }
	      step(p, line, col);
	      prefix(p, e, line, col, "+") || prefix(p, e, line, col, "-");
	      if(p == e || !is_dec(*p))
		goto token_done;
	      step(p, line, col);
	      while(p != e) {
		if(*p == '\'' && p+1 != e && is_dec(p[1])) {
		  step(p, line, col);
		  step(p, line, col);
		} else if(is_dec(*p))
		  step(p, line, col);
		else
		  break;
	      }
	      goto token_done;
	    }
	  }
	  // integer, suffixes
	  bool u1 = prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  prefix(p, e, line, col, "ll") || prefix(p, e, line, col, "LL") || prefix(p, e, line, col, "l") || prefix(p, e, line, col, "L");
	  if(!u1)
	    prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	  goto token_done;
	}

	if(p != e && is_dec(*p)) {
	  step(p, line, col);
	  while(p != e) {
	    if(*p == '\'' && p+1 != e && is_dec(p[1])) {
	      step(p, line, col);
	      step(p, line, col);
	    } else if(is_dec(*p))
	      step(p, line, col);
	    else
	      break;
	  }
	  if(p != e && (*p == '.' || (*p == 'p' || *p == 'P'))) {
	    // Floating point, no suffixes
	    if(*p == '.') {
	      step(p, line, col);
	      if(p == e || !is_dec(*p))
		goto token_done;
	      step(p, line, col);
	      while(p != e) {
		if(*p == '\'' && p+1 != e && is_dec(p[1])) {
		  step(p, line, col);
		  step(p, line, col);
		} else if(is_dec(*p))
		  step(p, line, col);
		else
		  break;
	      }
	      if(p == e || (*p != 'p' && *p != 'P'))
		goto token_done;
	    }
	    step(p, line, col);
	    prefix(p, e, line, col, "+") || prefix(p, e, line, col, "-");
	    if(p == e || !is_dec(*p))
	      goto token_done;
	    step(p, line, col);
	    while(p != e) {
	      if(*p == '\'' && p+1 != e && is_dec(p[1])) {
		step(p, line, col);
		step(p, line, col);
	      } else if(is_dec(*p))
		step(p, line, col);
	      else
		break;
	    }
	    goto token_done;
	  }
	}
	// integer, suffixes
	bool u1 = prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	prefix(p, e, line, col, "ll") || prefix(p, e, line, col, "LL") || prefix(p, e, line, col, "l") || prefix(p, e, line, col, "L");
	if(!u1)
	  prefix(p, e, line, col, "u") || prefix(p, e, line, col, "U");
	goto token_done;
      }

      // No idea, step one char only
      step(p, line, col);
    }

  token_done:
    tokens.push_back(new Token(ws, std::string(q, p), l, c, tokens.size()));
  }
}
