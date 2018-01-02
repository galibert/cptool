dofile("lib.lua")

inheritance_load("inheritance.txt")

files = filter_files(cp.scan(arg[1] .. "/src/mame/drivers"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

local devices_from_tag = {}
for l in io.lines("devices-in-drivers.txt") do
   local class, var, dtype, tag = l:match("(%S+) (%S+) (%S+) (.+)")
   devices_from_tag[class .. " " .. tag] = var
end

local method_to_devices = {}
for l in io.lines("methods-to-devices.txt") do
   local class, mth, tag = l:match("(%S+) (%S+) (.+)")
   local key = class .. " " .. mth
   if not method_to_devices[key] then
      method_to_devices[key] = {}
   end
   local mtd = method_to_devices[key]
   local needed = true
   for j=1,#mtd do
      if mtd[j] == tag then
	 needed = false
      end
   end
   if needed then
      mtd[#mtd+1] = tag
   end
end

function lookup_devices(m, c)
   local key = c .. " " .. m
   if method_to_devices[key] then
      return method_to_devices[key]
   end
   if not inheritance_info_i[c] then
      return nil
   end
   local r = {}
   local inh = inheritance_info_i[c]
   for i=1,#inh do
      local r1 = lookup_devices(m, inh[i])
      if r1 and #r1 > 0 then
	 for j=1,#r1 do
	    local na = true
	    for k=1,#r do
	       if r[k] == r1[j] then na = false end
	    end
	    if na then r[#r+1] = r1[j] end
	 end
      end
   end
   return r
end

function lookup_var(c, t)
   local key = c .. " " .. t
   if devices_from_tag[key] then
      return devices_from_tag[key]
   end
   if not inheritance_info[c] then
      return nil
   end
   local inh = inheritance_info[c]
   for i=1,#inh do
      local r1 = lookup_var(inh[i], t)
      if r1 then
	 return r1
      end
   end
   return nil
end

for fi=1,#files do
   local f = io.open(files[fi], "rb")
   local s = f:read("*all")
   f:close()

   local lex = cp.parse(s)
   local changed = false

   local c, m
   local ac = 0
   local pac = 0
   local i = 1
   while i <= #lex do
      local t = lex[i].token
      if (t == "READ8_MEMBER" or t == "READ16_MEMBER" or t == "READ32_MEMBER" or t == "READ64_MEMBER" or 
	  t == "WRITE8_MEMBER" or t == "WRITE16_MEMBER" or t == "WRITE32_MEMBER" or t == "WRITE64_MEMBER") and lex[i+4].token ~= ";" then
	 c = lex[i+2].token
	 m = lex[i+4].token
	 pac = ac
      end
      if t == "{" then
	 ac = ac + 1
      end
      if t == "}" then
	 ac = ac - 1
	 if ac == pac then
	    c = nil
	    m = nil
	 end
      end
      if lmatch(lex, i, { "space", ".", "device", "(", ")" }) then
	 if m and c then
	    local devs = lookup_devices(m, c)
	    if not devs or #devs == 0 then
	       print("No device associated to " .. c .. " " .. m)
	    elseif #devs > 1 then
	       print("Multiple devices associated to " .. c .. " " .. m)
	       for k=1,#devs do
		  print(string.format("- %s", devs[k]))
	       end
	    else
	       local var = lookup_var(c, devs[1])
	       if not var then
		  print("No variable associated to device " .. c .. " " .. devs[1])
	       else
		  if lex[i+5].token == "." then
		     i = lex:replace(i, i+5, var .. "->")
		     if lex[i+1].token == "safe_pc" then
			lex:replace(i+1, i+1, "pc")
		     end
		     if lex[i+1].token == "safe_pcbase" then
			lex:replace(i+1, i+1, "pcbase")
		     end
		     if lmatch(lex, i+1, { "execute", "(", ")", "." }) then
			lex:replace(i, i+4, "->")
		     end
		     if lmatch(lex, i+1, { "state", "(", ")", "." }) then
			lex:replace(i, i+4, "->")
		     end
		     changed = true
		  elseif lex[i-1].token == "&" then
		     i = lex:replace(i-1, i+4, var .. ".target()")
		     changed = true
		  else
		     i = lex:replace(i, i+4, "*" .. var)
		     changed = true
		  end
	       end
	    end
	    m = nil
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
