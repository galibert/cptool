dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   for i=1, #lex do
      local t = lex[i].token 
      if t == "ADDRESS_MAP_START" then
	 name = pick_parameter(lex, i, 1)
      end
      if t == "ADDRESS_MAP_END" then
	 name = nil
      end
      if t == "AM_IMPORT_FROM" then
	 if name then
	    print(string.format("%s %s", name, pick_parameter(lex, i, 1)))
	 end
      end
   end
end
