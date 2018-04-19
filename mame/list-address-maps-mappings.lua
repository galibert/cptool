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
      if t == "AM_DEVICE" or t == "AM_DEVICE8" or t == "AM_DEVICE16" or t == "AM_DEVICE32" then
	 if name then
	    local sz = 0
	    if t == "AM_DEVICE8"  then sz = 8 end
	    if t == "AM_DEVICE16" then sz = 16 end
	    if t == "AM_DEVICE32" then sz = 32 end
	    print(string.format("%s %d %s::%s", name, sz, pick_parameter(lex, i, 2), pick_parameter(lex, i, 3)))
	 end
      end
   end
end
