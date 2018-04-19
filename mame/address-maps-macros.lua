dofile("lib.lua")

local class_device_member = {}
for l in io.lines("devices-in-drivers-full.txt") do
   local class, tag, var = l:match("(%S+) (%S+) (%S+)")
   if not class_device_member[class] then
      class_device_member[class] = {}
   end
   class_device_member[class][tag] = var
end

local am_infos = {}
for l in io.lines("am-infos-bh.txt") do
   local meth, dw, aw, as, en = l:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
   dw = tonumber(dw)
   aw = tonumber(aw)
   as = tonumber(as)
   en = tonumber(en)
   na = dw >> (3+as)
   am_infos[meth] = { dw=dw, dwb=dw>>3, aw=aw, as=as, en=en, na=na }
end

function devname(class, tag)
   if class_device_member[class] and class_device_member[class][tag] then
      return class_device_member[class][tag]
   end
   return tag
end

local maxmask = { [8] = 0xff, [16] = 0xffff, [32] = 0xffffffff, [64] = 0xffffffffffffffff }

function reprint(adr, ref)
   local l = #ref - 2
   local b, h
   if ref:sub(1,2) == "0X" then
      b = string.format("%X", adr)
      h = "0X"
   else
      b = string.format("%x", adr)
      h = "0x"
   end
   while #b < l do
      b = "0" .. b
   end
   return h .. b
end

function umask(info, range, umask)
   while umask:sub(#umask) == "L" or umask:sub(#umask) == "U" or umask:sub(#umask) == "l" or umask:sub(#umask) == "u" do
      umask = umask:sub(1, #umask-1)
   end
   mask = tonumber(umask)

   rs = tonumber(range[1])
   re = tonumber(range[2])

   if mask == maxmask[info.dw] then
      return ""
   end

   local s
   if info.dw == 16 then
      mask = mask & 0xffff
      if umask:sub(1,2) == "0X" then
	 s = string.format(".umask16(0X%04X)", mask)
      else
	 s = string.format(".umask16(0x%04x)", mask)
      end
   elseif info.dw == 32 then
      mask = mask & 0xffffffff
      if umask:sub(1,2) == "0X" then
	 s = string.format(".umask32(0X%08X)", mask)
      else
	 s = string.format(".umask32(0x%08x)", mask)
      end
   else
      if umask:sub(1,2) == "0X" then
	 s = string.format(".umask64(0X%016X)", mask)
      else
	 s = string.format(".umask64(0x%016x)", mask)
      end
   end
   if rs ~= re - info.na + 1 then
      return s
   end

   local bs = 8 >> info.as
   if info.as == 3 then
      bs = 16
   end

   local bsm = maxmask[bs]

   local shift = 0
   local spanstart, spanend
   local id = 0
   while shift < info.dw do
      local v = (mask >> shift) & bsm
      if v == 0 then
	 if spanstart and not spanend then
	    spanend = id - 1
	 end
      elseif v == bsm then
	 if spanend then
	    return s
	 end
	 if not spanstart then
	    spanstart = id
	 end
      else
	 return s
      end
      id = id + 1
      shift = shift + bs
   end
   if spanstart and not spanend then
      spanend = id - 1
   end

   if info.en == 0 then
      re = rs + spanend
      rs = rs + spanstart
   else
      rs = re - spanstart
      re = re - spanend
   end

   range[1] = reprint(rs, range[1])
   range[2] = reprint(re, range[2])
   
--   print(string.format("umask %s %s %x %d-%d (%d)", range[1], range[2], mask, spanstart, spanend, bs))

   return ""
end

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp" })

transformers = {
   { { "AM_RAM" },
      function(lex, i, am_info, range)
	 return ".ram()"
      end
   },
   { { "AM_ROM" },
      function(lex, i, am_info, range)
	 return ".rom()"
      end
   },
   { { "AM_READONLY" },
      function(lex, i, am_info, range)
	 return ".readonly()"
      end
   },
   { { "AM_WRITEONLY" },
      function(lex, i, am_info, range)
	 return ".writeonly()"
      end
   },
   { { "AM_NOP" },
      function(lex, i, am_info, range)
	 return ".noprw()"
      end
   },
   { { "AM_READNOP" },
      function(lex, i, am_info, range)
	 return ".nopr()"
      end
   },
   { { "AM_WRITENOP" },
      function(lex, i, am_info, range)
	 return ".nopw()"
      end
   },
   { { "AM_UNMAP" },
      function(lex, i, am_info, range)
	 return ".unmaprw()"
      end
   },
   { { "AM_READUNMAP" },
      function(lex, i, am_info, range)
	 return ".unmapr()"
      end
   },
   { { "AM_WRITEUNMAP" },
      function(lex, i, am_info, range)
	 return ".unmapw()"
      end
   },
   { { "AM_READ_PORT", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".portr(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_WRITE_PORT", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".portw(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_READWRITE_PORT", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".portrw(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_REGION", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".region(" .. pick_parameter(lex, i, 1) .. ", " .. pick_parameter(lex, i, 2) .. ")"
      end
   },
   { { "AM_SHARE", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".share(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_MASK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".mask(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_MIRROR", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".mirror(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_SELECT", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".select(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_READ_BANK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".bankr(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_WRITE_BANK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".bankw(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_READWRITE_BANK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".bankrw(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_ROMBANK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".bankr(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_RAMBANK", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".bankrw(" .. pick_parameter(lex, i, 1) .. ")"
      end
   },
   { { "AM_SETOFFSET", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".setoffset(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
      end
   },
   { { "AM_DEVSETOFFSET", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".setoffset(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
   { { "AM_READ", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
      end
   },
   { { "AM_READ8", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_READ16", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_READ32", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_WRITE", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
      end
   },
   { { "AM_WRITE8", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_WRITE16", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_WRITE32", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 2))
      end
   },
   { { "AM_READWRITE", "(", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".rw(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "), FUNC(" .. class .. "::" .. pick_parameter(lex, i, 2) .. "))"
      end
   },
   { { "AM_READWRITE8", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".rw(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "), FUNC(" .. class .. "::" .. pick_parameter(lex, i, 2) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 3))
      end
   },
   { { "AM_READWRITE16", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".rw(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "), FUNC(" .. class .. "::" .. pick_parameter(lex, i, 2) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 3))
      end
   },
   { { "AM_READWRITE32", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".rw(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "), FUNC(" .. class .. "::" .. pick_parameter(lex, i, 2) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 3))
      end
   },
   { { "AM_RAM_READ", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".ram().r(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
      end
   },
   { { "AM_RAM_WRITE", "(", "", ")" },
      function(lex, i, am_info, range)
	 return ".ram().w(this, FUNC(" .. class .. "::" .. pick_parameter(lex, i, 1) .. "))"
      end
   },
   { { "AM_DEVICE", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".m(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. pick_parameter(lex, i, 2) .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
   { { "AM_DEVICE8", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".m(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. pick_parameter(lex, i, 2) .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVICE16", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".m(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. pick_parameter(lex, i, 2) .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVICE32", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 return ".m(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. pick_parameter(lex, i, 2) .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVREAD", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".r(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
   { { "AM_DEVREAD8", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".r(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVREAD16", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".r(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVREAD32", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".r(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVWRITE", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".w(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
   { { "AM_DEVWRITE8", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".w(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVWRITE16", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".w(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVWRITE32", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".w(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 4))
      end
   },
   { { "AM_DEVREADWRITE", "(", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".rw(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "), FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 4) .. "))"
      end
   },
   { { "AM_DEVREADWRITE8", "(", "", ",", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".rw(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "), FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 4) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 5))
      end
   },
   { { "AM_DEVREADWRITE16", "(", "", ",", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".rw(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "), FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 4) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 5))
      end
   },
   { { "AM_DEVREADWRITE32", "(", "", ",", "", ",", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".rw(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "), FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 4) .. "))" .. umask(am_info, range, pick_parameter(lex, i, 5))
      end
   },
   { { "AM_RAM_DEVREAD", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".ram().r(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
   { { "AM_RAM_DEVWRITE", "(", "", ",", "", ",", "", ")" },
      function(lex, i, am_info, range)
	 local cl = pick_parameter(lex, i, 2)
	 return ".ram().w(" .. devname(class, pick_parameter(lex, i, 1)) .. ", FUNC(" .. cl .. "::" .. pick_parameter(lex, i, 3) .. "))"
      end
   },
}

for fi=1,#files do
--   print(files[fi])
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local changed = false
   local aminfo = nil
   local range = nil
   local i = 1
   while i <= #lex do
      if cur_line and (lex[i].line ~= cur_line or lex[i].token:sub(1, 2) == "//" or lex[i].token:sub(1, 2) == "/*" or lex[i].token == ";" or lex[i].token == ".") and range then
	 cur_str = "map(" .. range[1] .. ", " .. range[2] .. ")" .. cur_str
	 local en = i-1
	 if lex[i].token == ";" then
	    en = i
	 end
	 local suffix = ";"
	 if lex[i].token == "." then
	    suffix = ""
	 end
	 i = lex:replace(cur_pos, en, cur_str .. suffix)
	 changed = true
	 cur_pos = nil
	 cur_line = nil
	 cur_str = nil
	 range = nil
      end
      local t = lex[i].token
      if lmatch(lex, i, { "ADDRESS_MAP_START", "(", "", "::", "", ")" }) then
	 meth = pick_parameter(lex, i, 1)
	 am_info = am_infos[meth]
	 class, method = meth:match("(%S+)::(%S+)")
	 if am_info then
	    print(meth)
	    i = lex:replace(i, i+5, "void " .. meth .. "(address_map &map)\n{")
	    changed = true
	 else
	    print("Skipping " .. meth)
	 end
      end
      if am_info then
	 if lmatch(lex, i, { "ADDRESS_MAP_END" }) then
	    i = lex:replace(i, i, "}")
	    meth = nil
	    am_info = nil
	 elseif lmatch(lex, i, { "AM_RANGE", "(", "", ",", "", ")" }) then
	    cur_pos = i
	    cur_line = lex[i].line
	    cur_str = ""
	    range = { pick_parameter(lex, i, 1),  pick_parameter(lex, i, 2) }
	    i = lmatch(lex, i, { "AM_RANGE", "(", "", ",", "", ")" })

	 elseif lmatch(lex, i, { "AM_IMPORT_FROM", "(" }) then
	    i = lex:replace(i, skip_parameter(lex, i+2, 1), pick_parameter(lex, i, 1) .. "(map);")

	 elseif lmatch(lex, i, { "ADDRESS_MAP_GLOBAL_MASK", "(" }) then
	    i = lex:replace(i, skip_parameter(lex, i+2, 1), "map.global_mask(" .. pick_parameter(lex, i, 1) .. ");")
	 elseif lmatch(lex, i, { "ADDRESS_MAP_UNMAP_LOW" }) then
	    i = lex:replace(i, i, "map.unmap_value_low();")
	 elseif lmatch(lex, i, { "ADDRESS_MAP_UNMAP_HIGH" }) then
	    i = lex:replace(i, i, "map.unmap_value_high();")

	 elseif cur_str then
	    local l = 1
	    while l and transformers[l] do
	       local ni = lmatch(lex, i, transformers[l][1])
	       if ni then
		  cur_str = cur_str .. transformers[l][2](lex, i, am_info, range)
		  i = ni
		  l = nil
	       else
		  l = l + 1
	       end
	    end

	    if l then
	       print("Lost at line " .. cur_line .. " - " .. cur_str .. " (" .. lex[i].token .. ")")
	       cur_pos = nil
	       cur_line = nil
	       cur_str = nil
	       range = nil
	       i = i + 1
	    end
	 else
	    i = i + 1
	 end
      else
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
