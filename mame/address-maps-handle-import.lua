dofile("lib.lua")
inheritance_load("inheritance.txt")

local address_maps = {}
for l in io.lines("address-maps.txt") do
   local class, method = l:match("(%S+)::(%S+)")
   if not address_maps[method] then
      address_maps[method] = {}
   end
   am = address_maps[method]
   am[#am + 1] = class
end

local am_infos = {}
for l in io.lines("am-infos-all.txt") do
   local meth, info = l:match("(%S+) (.+)")
   am_infos[meth] = info
end

for l in io.lines("address-maps-imports.txt") do
   local map1, map2 = l:match("(%S+) (.+)")
   local class1, method1 = map1:match("(%S+)::(%S+)")
   local class2, method2 = map2:match("(%S+)::(%S+)")
   if not method2 then
      local cl = address_maps[map2]
      if cl then
	 for i=1,#cl do
	    local c = cl[i]
	    if c == class1 or inherits_from(class1, c) then
	       class2 = c
	       method2 = map2
	       map2 = class2 .. "::" .. method2
	       break
	    end
	 end
      end
      if not class2 then
	 io.stderr:write("Not found: " .. l .. "\n")
      end
   end

   if class2 and not am_infos[map2] and am_infos[map1] then
      print(map2 .. " " .. am_infos[map1])
   end
end
