dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src/mame/drivers"), { ".cpp", ".hxx" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   for i=1, #lex do
      local t = lex[i].token 
      if t == "GAME" or t == "GAMEL" then
	 local m = pick_parameter(lex, i, 4)
	 local c = pick_parameter(lex, i, 6)
	 print(string.format("%s %s", c, m))
      end
      if t == "CONS" or t == "COMP" or t == "SYST" then
	 local m = pick_parameter(lex, i, 5)
	 local c = pick_parameter(lex, i, 7)
	 print(string.format("%s %s", c, m))
      end
   end
end

