dofile("lib.lua")

inheritance_load("inheritance.txt")

local class_device_member = {}
for l in io.lines("devices-in-drivers-full.txt") do
   local class, tag, var = l:match("(%S+) (%S+) (%S+)")
   if not class_device_member[class] then
      class_device_member[class] = {}
   end
   class_device_member[class][tag] = var
end

function devname(class, tag)
   if class_device_member[class] and class_device_member[class][tag] then
      return class_device_member[class][tag]
   end
   return tag
end

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

files = { arg[1] .. "/src/mame/drivers/oric.cpp" }

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local changed = false
   local i = 1
   while i <= #lex do
      if cur_line and lex[i].line ~= cur_line then
	 i = lex:replace(cur_pos, i-1, cur_str .. ";")
	 changed = true
	 cur_pos = nil
	 cur_line = nil
	 cur_str = nil
      end
      local t = lex[i].token
      if lmatch(lex, i, { "ADDRESS_MAP_START", "(", "", "::", "", ")" }) then
	 meth = pick_parameter(lex, i, 1)
	 class, method = meth:match("(%S+)::(%S+)")
	 print(meth)
	 i = lex:replace(i, i+5, "void " .. meth .. "(address_map &map)")
	 changed = true
      elseif lmatch(lex, i, { "ADDRESS_MAP_END" }) then
	 i = lex:replace(i, i, "}")
	 meth = nil
      elseif lmatch(lex, i, { "AM_RANGE", "(", "", ",", "", ")" }) then
	 cur_pos = i
	 cur_line = lex[i].line
	 cur_str = "map(" .. pick_parameter(lex, i, 1) .. ", " .. pick_parameter(lex, i, 2) .. ")"
	 i = i + 6
      elseif cur_pos and lmatch(lex, i, { "AM_RAM" }) then
	 cur_str = cur_str .. ".ram()"
	 i = i + 1
      elseif cur_pos and lmatch(lex, i, { "AM_SHARE", "(", "", ")" }) then
	 cur_str = cur_str .. ".share(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_MASK", "(", "", ")" }) then
	 cur_str = cur_str .. ".mask(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_MIRROR", "(", "", ")" }) then
	 cur_str = cur_str .. ".mirror(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_SELECT", "(", "", ")" }) then
	 cur_str = cur_str .. ".select(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_READ_BANK", "(", "", ")" }) then
	 cur_str = cur_str .. ".bankr(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_WRITE_BANK", "(", "", ")" }) then
	 cur_str = cur_str .. ".bankw(" .. pick_parameter(lex, i, 1) .. ")"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_READ", "(", "", ")" }) then
	 cur_str = cur_str .. ".r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_WRITE", "(", "", ")" }) then
	 cur_str = cur_str .. ".w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
	 i = i + 4
      elseif cur_pos and lmatch(lex, i, { "AM_READWRITE", "(", "", ",", "", ")" }) then
	 cur_str = cur_str .. ".rw(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. ", FUNC(" .. class .. "::" .. pick_parameter(lex, i, 2) .. "))"
	 i = i + 6
      elseif cur_pos and lmatch(lex, i, { "AM_DEVREADWRITE", "(", "", ",", "", ",", "", ",", "", ")" }) then
	 cur_str = cur_str .. ".rw(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. class .. "::" .. pick_parameter(lex, i, 3) .. ", FUNC(" .. class .. "::" .. pick_parameter(lex, i, 4) .. "))"
	 i = i + 10
      else
	 if cur_str then
	    print("Lost at line " .. cur_line .. " - " .. cur_str)
	    cur_pos = nil
	    cur_line = nil
	    cur_str = nil
	 end
	 i = i + 1
      end
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
