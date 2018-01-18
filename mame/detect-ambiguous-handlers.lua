dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

types =  {
   DECLARE_READ8_MEMBER   = { "r", 8  },
   DECLARE_READ16_MEMBER  = { "r", 16 },
   DECLARE_READ32_MEMBER  = { "r", 32 },
   DECLARE_READ64_MEMBER  = { "r", 64 },
   DECLARE_WRITE8_MEMBER  = { "w", 8  },
   DECLARE_WRITE16_MEMBER = { "w", 16 },
   DECLARE_WRITE32_MEMBER = { "w", 32 },
   DECLARE_WRITE64_MEMBER = { "w", 64 }
}

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local handlers = {}

   local i = 1
   while i <= #lex do
      local t = lex[i].token 
      if (t == "class" or t == "struct") and lex[i+2].token == ":" then
	 local cn = lex[i+1].token
	 i = i + 3
	 while lex[i].token ~= "" and lex[i].token ~= "{" do
	    i = i + 1
	 end
	 if lex[i].token == "{" then
	    i = i + 1
	    local ac = 1
	    while i <= #lex and ac > 0 do
	       t = lex[i].token
	       if types[t] then
		  local rw = types[t][1]
		  local sz = types[t][2]
		  local mn = pick_parameter(lex, i, 1)
		  if not handlers[cn] then
		     handlers[cn] = { r = { }, w = { } }
		  end
		  local h = handlers[cn][rw]
		  local h1 = h[mn]
		  if not h1 then
		     h1 = {}
		     h[mn] = h1
		  end
		  h1[#h1+1] = sz
	       end
	       if t == "{" then
		  ac = ac + 1
	       end
	       if t == "}" then
		  ac = ac - 1
	       end
	       i = i + 1
	    end
	 end
      else
	 i = i + 1
      end
   end
   for k,v1 in pairs(handlers) do
      for rw, v2 in pairs(v1) do
	 for m, v3 in pairs(v2) do
	    if #v3 > 1 then
	       for j=1,#v3 do
		  print(string.format("%s %s %s %d", k, m, rw, v3[j]))
	       end
	    end
	 end
      end
   end
end