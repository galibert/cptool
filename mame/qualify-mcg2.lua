dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local i = 1
   while i <= #lex do
      if lmatch(lex, i, { "MACHINE_CONFIG_START", "(", "", ")" }) then
      end
      i = i + 1
   end
end
