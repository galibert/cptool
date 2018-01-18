dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

local mapping = {}
for l in io.lines("ambh.txt") do
   local class, meth1, rw, sz, meth2 = l:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
   if not mapping[class] then
      mapping[class] = {}
   end
   if not mapping[class][meth1] then
      mapping[class][meth1] = {}
   end
   if not mapping[class][meth1][rw] then
      mapping[class][meth1][rw] = {}
   end
   mapping[class][meth1][rw][tonumber(sz)] = meth2
end

local changed

function patch(lex, i, rw, sz, cli, mti)
   if not sz then
      return
   end
   local cn = pick_parameter(lex, i, cli)
   local meth1 = pick_parameter(lex, i, mti)
   if not mapping[cn] or not mapping[cn][meth1] or not mapping[cn][meth1][rw] then
      return
   end
   local meth2 = mapping[cn][meth1][rw][sz]
   if not meth2 then
      return
   end
   set_parameter(lex, i, mti, meth2)
   changed = true
end

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local i = 1
   local cn = nil
   local dsz = nil
   changed = false
   while i <= #lex do
      local t = lex[i].token 
      if t == "ADDRESS_MAP_START" then
	 cn = pick_parameter(lex, i, 4)
	 dsz = tonumber(pick_parameter(lex, i, 3))
      end
      if t == "ADDRESS_MAP_END" then
	 cn = nil
	 dsz = nil
      end
      if t == "AM_DEVWRITE" or t == "AM_DEVWRITE_MOD" or t == "AM_RAM_DEVWRITE" then
	 patch(lex, i, "w", dsz, 2, 3)
      end
      if t == "AM_DEVWRITE8" or t == "AM_DEVWRITE8_MOD" then
	 patch(lex, i, "w", 8, 2, 3)
      end
      if t == "AM_DEVWRITE16" or t == "AM_DEVWRITE16_MOD" then
	 patch(lex, i, "w", 16, 2, 3)
      end
      if t == "AM_DEVWRITE32" or t == "AM_DEVWRITE32_MOD" then
	 patch(lex, i, "w", 32, 2, 3)
      end
      if t == "AM_DEVWRITE64" or t == "AM_DEVWRITE64_MOD" then
	 patch(lex, i, "w", 64, 2, 3)
      end
      if t == "AM_DEVREAD" or t == "AM_DEVREAD_MOD" or t == "AM_RAM_DEVREAD" then
	 patch(lex, i, "r", dsz, 2, 3)
      end
      if t == "AM_DEVREAD8" or t == "AM_DEVREAD8_MOD" then
	 patch(lex, i, "r", 8, 2, 3)
      end
      if t == "AM_DEVREAD16" or t == "AM_DEVREAD16_MOD" then
	 patch(lex, i, "r", 16, 2, 3)
      end
      if t == "AM_DEVREAD32" or t == "AM_DEVREAD32_MOD" then
	 patch(lex, i, "r", 32, 2, 3)
      end
      if t == "AM_DEVREAD64" or t == "AM_DEVREAD64_MOD" then
	 patch(lex, i, "r", 64, 2, 3)
      end
      if t == "AM_DEVREADWRITE" or t == "AM_DEVREADWRITE_MOD" then
	 patch(lex, i, "r", dsz, 2, 3)
	 patch(lex, i, "w", dsz, 2, 4)
      end
      if t == "AM_DEVREADWRITE8" or t == "AM_DEVREADWRITE8_MOD" then
	 patch(lex, i, "r", 8, 2, 3)
	 patch(lex, i, "w", 8, 2, 4)
      end
      if t == "AM_DEVREADWRITE16" or t == "AM_DEVREADWRITE16_MOD" then
	 patch(lex, i, "r", 16, 2, 3)
	 patch(lex, i, "w", 16, 2, 4)
      end
      if t == "AM_DEVREADWRITE32" or t == "AM_DEVREADWRITE32_MOD" then
	 patch(lex, i, "r", 32, 2, 3)
	 patch(lex, i, "w", 32, 2, 4)
      end
      if t == "AM_DEVREADWRITE64" or t == "AM_DEVREADWRITE64_MOD" then
	 patch(lex, i, "r", 64, 2, 3)
	 patch(lex, i, "w", 64, 2, 4)
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
