dofile("lib.lua")

inheritance_load("inheritance.txt")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

local mchg_to_class = {}
for l in io.lines("mchg2.txt") do
   local class, meth = l:match("(%S+) (%S+)")
   mchg_to_class[meth] = class
end

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)
   local changed = false
   for i=1, #lex do
      if lmatch(lex, i, { "MACHINE_CONFIG_START", "(", "", ")" }) then
	 local t = lex[i+2].token
	 local c = mchg_to_class[t]
	 if c then
	    local j = i
	    if lex[j-1].token == "static" then
	       j = j - 1
	    end
	    print(c.."::"..t)
	    repl = "MACHINE_CONFIG_START(" .. c .. "::" .. t .. ")"
	    i = lex:replace(j, i+3, repl)
	    changed = true
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
