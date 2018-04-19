
spacemap = {}

for l in io.lines("address_spaces.txt") do
   local cpu, id, info = l:match("(%S+) (%S+) (.+)")
   if not spacemap[cpu] then
      spacemap[cpu] = {}
   end
   spacemap[cpu][id] = info
end

spacenames = {}

for l in io.lines("amnames.txt") do
   local id, name = l:match("(%S+) (%S+)")
   spacenames[name] = id
end

for l in io.lines("am-infos-1.txt") do
   local map, dw, aw, as, en = l:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
   if en then
      print(l)
   else
      local map, cpu, name = l:match("(%S+) (%S+) (%S+)")
      if spacenames[name] then
	 name = spacenames[name]
      end
      local info = spacemap[cpu]
      if not info then
	 io.stderr:write("Unknown cpu " .. cpu .. "\n")
      else
	 info = info[name]
	 if not info then
	    io.stderr:write("Unknown space " .. name .. " on cpu " .. cpu .. "\n")
	 else
	    print(string.format("%s %s", map, info))
	 end
      end
   end
end
