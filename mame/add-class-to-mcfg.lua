dofile("lib.lua")

local class_to_mchg = {}
local mchg_to_class = {}
for l in io.lines("mchg.txt") do
   local mchg, class = l:match("(%S+) (%S+)")
   if not class_to_mchg[class] then
      class_to_mchg[class] = {}
   end
   class_to_mchg[class][#class_to_mchg[class]+1] = mchg
   mchg_to_class[mchg] = class
end

files = filter_files(cp.scan(arg[1] .. "/src/mame"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local changed = false
   local i = 1
   while i <= #lex do
      local t = lex[i].token
      if lmatch(lex, i, { "MACHINE_CONFIG_START", "(", "", ")" }) then
	 local start = i
	 if lex[i-1].token == "static" then
	    start = i-1
	 end
	 mchg_name = lex[i+2].token
	 if  mchg_to_class[mchg_name] then
	    i = lex:replace(start, i+3, "MACHINE_CONFIG_START(" .. mchg_to_class[mchg_name] .. "::" .. mchg_name .. ")")
	    changed = true
	 else
	    print("Unclassified machine config: " .. mchg_name)
	 end
      end
      if lmatch(lex, i, { "MACHINE_CONFIG_DERIVED", "(", "", ",", "", ")" }) then
	 local start = i
	 if lex[i-1].token == "static" then
	    start = i-1
	 end
	 mchg_name = lex[i+2].token
	 inh_name = lex[i+4].token
	 if  mchg_to_class[mchg_name] then
	    i = lex:replace(start, i+5, "MACHINE_CONFIG_DERIVED(" .. mchg_to_class[mchg_name] .. "::" .. mchg_name ..", " .. inh_name .. ")")
	    changed = true
	 else
	    print("Unclassified machine config: " .. mchg_name)
	 end
      end
      if (t == "class" or t == "struct") and lex[i+2].token == ":" then
	 local class = lex[i+1].token
	 local mchg_name = class_to_mchg[class]
	 if mchg_name then
            while lex[i].token ~= "{" and lex[i].token ~= ";" do
               i = i + 1
            end
            if lex[i].token == "{" then
	       i = i + 1
	       local lvl = 1
	       local in_public = false
	       while i < #lex do
		  local t = lex[i].token
		  if t == "{" then
		     lvl = lvl + 1
		  end
		  if (in_public and (t == "protected" or t == "private") and lex[i+1].token == ":") or (t == "}" and lvl == 1) then
		     for k=1,#mchg_name do
			local decl = "void " .. mchg_name[k] .. "(machine_config &config);"
			i = lex:insert_line_before(i, decl)
		     end
		     changed = true
		     break
		  end
		  if t == "public" and lex[i+1].token == ":" then
		     in_public = true
		  end
		  if t == "}" then
		     lvl = lvl - 1
		     if lvl == 0 then
			print("Failed on " .. class .. "::" .. mcgh_name[1])
			break
		     end
		  end
		  i = i + 1
	       end
	    end
	 end
      end
      i = i + 1
   end

   if changed then
      local s1 = lex:str()
      if s1 ~= s then
         f = io.open(files[fi], "wb")
         f:write(s1)
         f:close()
      end
   end
end
