dofile("lib.lua")

inheritance_load("inheritance.txt")

files = filter_files(cp.scan(arg[1] .. "/src/mame/drivers"), { ".cpp", ".hxx" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local mchgs = {}
   for i=1, #lex do
      local t = lex[i].token 
      local m, c
      if t == "GAME" or t == "GAMEL" then
	 m = pick_parameter(lex, i, 4)
	 c = pick_parameter(lex, i, 6)
      end
      if t == "CONS" or t == "COMP" or t == "SYST" then
	 m = pick_parameter(lex, i, 5)
	 c = pick_parameter(lex, i, 7)
      end
      if m then
	 if mchgs[m] and mchgs[m] ~= c then
	    if inherits_from(mchgs[m], c) then
	       mchgs[m] = c
	    elseif not inherits_from(c, mchgs[m]) then
	       io.stderr:write(string.format("Conflict on %s between %s and %s\n", m, c, mchgs[m]))
	    end
	 else
	    mchgs[m] = c
	 end
      end
   end

   for m,c in pairs(mchgs) do
      io.write(string.format("%s %s\n", m, c))
   end
end

