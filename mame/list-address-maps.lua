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
	 print(pick_parameter(lex, i, 1))
      end
   end
end
