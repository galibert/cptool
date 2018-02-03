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
	 class = pick_parameter(lex, i, 4)
	 print(string.format("%s %s", class, name));
      end
   end
end
