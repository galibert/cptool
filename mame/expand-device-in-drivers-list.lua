dofile("lib.lua")

inheritance_load("inheritance.txt")

local class_device_member = {}
for l in io.lines("devices-in-drivers.txt") do
   local class, var, dtype, tag = l:match("(%S+) (%S+) (%S+) (.+)")
   local cl = list_derivatives_of(class)
   cl[#cl+1] = class
   for j=1,#cl do
      local cl1 = cl[j]
      if not class_device_member[cl1] then
	 class_device_member[cl1] = {}
      end
      if class_device_member[cl1][tag] then
	 print("Collision " .. cl1 .. " " .. tag .. " " .. var .. " " .. class_device_member[cl1][tag])
      end
      class_device_member[cl1][tag] = var
      print(cl1 .. " " .. tag .. " " .. var)
   end
end
