dofile("lib.lua")

local class_to_amap = {}
for l in io.lines("address-maps.txt") do
   local class, amap = l:match("(%S+) (%S+)")
   if not class_to_amap[class] then
      class_to_amap[class] = {}
   end
   class_to_amap[class][#class_to_amap[class]+1] = amap
end

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local changed = false
   local i = 1
   while i <= #lex do
      local t = lex[i].token
      if lmatch(lex, i, { "ADDRESS_MAP_START", "(", "", ",", "", ",", "", ",", "", ")" }) then
	 local start = i
	 if lex[i-1].token == "static" then
	    start = i-1
	 end
	 class = pick_parameter(lex, i, 4)
	 meth = pick_parameter(lex, i, 1)
	 print(string.format("found implementation of %s::%s", class, meth))
	 i = lex:replace(start, i+9, "ADDRESS_MAP_START(" .. class .. "::" .. meth .. ")")
	 changed = true
      end
      if lmatch(lex, i, { "DEVICE_ADDRESS_MAP_START", "(", "", ",", "", ",", "", ")" }) then
	 local start = i
	 class = pick_parameter(lex, i, 3)
	 width = pick_parameter(lex, i, 2)
	 meth = pick_parameter(lex, i, 1)
	 print(string.format("found implementation of %s::%s", class, meth))
	 i = lex:replace(start, i+7, "ADDRESS_MAP_START(" .. class .. "::" .. meth .. ")")
	 changed = true
      end
      if lmatch(lex, i, { "DECLARE_ADDRESS_MAP", "(", "", ",", "", ")" }) then
	 local start = i
	 meth = pick_parameter(lex, i, 1)
	 print(string.format("found declaration of %s::%s", class, meth))
	 i = lex:replace(start, i+5, "void " .. meth .. "(address_map &map)")
	 changed = true
      end
      if (t == "class" or t == "struct") and lex[i+2].token == ":" then
	 class = lex[i+1].token
	 local amap_name = class_to_amap[class]
	 if amap_name then
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
		     print(string.format("adding declarations to %s", class))
		     for k=1,#amap_name do
			local decl = "void " .. amap_name[k] .. "(address_map &map);"
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
			print("Failed on " .. class .. "::" .. amap_name[1])
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
