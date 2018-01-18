dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

wl = {
   "AM_WRITE", "AM_WRITE8", "AM_WRITE16", "AM_WRITE32", "AM_WRITE64",
   "AM_READWRITE", "AM_READWRITE8", "AM_READWRITE16", "AM_READWRITE32", "AM_READWRITE64",
   "AM_DEVWRITE", "AM_DEVWRITE8", "AM_DEVWRITE16", "AM_DEVWRITE32", "AM_DEVWRITE64",
   "AM_DEVREADWRITE", "AM_DEVREADWRITE8", "AM_DEVREADWRITE16", "AM_DEVREADWRITE32", "AM_DEVREADWRITE64",
   "AM_DEVWRITE_MOD", "AM_DEVWRITE8_MOD", "AM_DEVWRITE16_MOD", "AM_DEVWRITE32_MOD", "AM_DEVWRITE64_MOD",
   "AM_DEVREADWRITE_MOD", "AM_DEVREADWRITE8_MOD", "AM_DEVREADWRITE16_MOD", "AM_DEVREADWRITE32_MOD", "AM_DEVREADWRITE64_MOD",
   "AM_DEVICE", "AM_DEVICE8", "AM_DEVICE16", "AM_DEVICE32", "AM_DEVICE64",
   "AM_RAM", "AM_RAMBANK", "AM_RAM_READ", "AM_RAM_WRITE", "AM_RAM_DEVREAD", "AM_RAM_DEVWRITE"
}

rl = {
   "AM_READ", "AM_READ8", "AM_READ16", "AM_READ32", "AM_READ64",
   "AM_READWRITE", "AM_READWRITE8", "AM_READWRITE16", "AM_READWRITE32", "AM_READWRITE64",
   "AM_DEVREAD", "AM_DEVREAD8", "AM_DEVREAD16", "AM_DEVREAD32", "AM_DEVREAD64",
   "AM_DEVREADWRITE", "AM_DEVREADWRITE8", "AM_DEVREADWRITE16", "AM_DEVREADWRITE32", "AM_DEVREADWRITE64",
   "AM_DEVREAD_MOD", "AM_DEVREAD8_MOD", "AM_DEVREAD16_MOD", "AM_DEVREAD32_MOD", "AM_DEVREAD64_MOD",
   "AM_DEVREADWRITE_MOD", "AM_DEVREADWRITE8_MOD", "AM_DEVREADWRITE16_MOD", "AM_DEVREADWRITE32_MOD", "AM_DEVREADWRITE64_MOD",
   "AM_DEVICE", "AM_DEVICE8", "AM_DEVICE16", "AM_DEVICE32", "AM_DEVICE64",
   "AM_RAM", "AM_ROM", "AM_ROMBANK", "AM_RAMBANK", "AM_RAM_READ", "AM_RAM_WRITE", "AM_RAM_DEVREAD", "AM_RAM_DEVWRITE"
}

mask = {
   "AM_DEVICE8", "AM_DEVICE16", "AM_DEVICE32", "AM_DEVICE64",
   "AM_DEVREAD8", "AM_DEVREAD16", "AM_DEVREAD32", "AM_DEVREAD64",
   "AM_DEVREADWRITE8", "AM_DEVREADWRITE16", "AM_DEVREADWRITE32", "AM_DEVREADWRITE64",
   "AM_DEVREADWRITE8_MOD", "AM_DEVREADWRITE16_MOD", "AM_DEVREADWRITE32_MOD", "AM_DEVREADWRITE64_MOD",
   "AM_DEVREAD8_MOD", "AM_DEVREAD16_MOD", "AM_DEVREAD32_MOD", "AM_DEVREAD64_MOD",
   "AM_DEVWRITE8", "AM_DEVWRITE16", "AM_DEVWRITE32", "AM_DEVWRITE64",
   "AM_DEVWRITE8_MOD", "AM_DEVWRITE16_MOD", "AM_DEVWRITE32_MOD", "AM_DEVWRITE64_MOD",
   "AM_READ8", "AM_READ16", "AM_READ32", "AM_READ64",
   "AM_READWRITE8", "AM_READWRITE16", "AM_READWRITE32", "AM_READWRITE64",
   "AM_WRITE8", "AM_WRITE16", "AM_WRITE32", "AM_WRITE64"
}

is_w = make_hash(wl)
is_r = make_hash(rl)
has_m = make_hash(mask)

function check(f, n, r)
   if #r < 2 then
      return
   end
   for i=1,#r-1 do
      for j=i+1,#r do
	 if r[i][1] and r[i][2] and r[j][1] and r[j][2] then
	    if ((r[i].w and r[j].w) or (r[i].r and r[j].r)) and (not r[i].mask or not r[j].mask or (r[i].mask & r[j].mask) ~= 0) and not (r[i][1] > r[j][2] or r[i][2] < r[j][1]) then
	       print(string.format("%s %s %x-%x %x vs. %x-%x %x", f, n, r[i][1], r[i][2], r[i].mask or 0, r[j][1], r[j][2], r[j].mask or 0))
	    end
	 end
      end
   end
end

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local i = 1
   local name = nil
   local ranges = {}
   while i <= #lex do
      local t = lex[i].token 
      if t == "ADDRESS_MAP_START" or t == "DEVICE_ADDRESS_MAP_START" then
	 name = pick_parameter(lex, i, 1)
      end
      if t == "ADDRESS_MAP_END" then
	 check(files[fi], name, ranges)
	 name = nil
	 ranges = {}
      end
      if t == "AM_RANGE" then
	 ranges[#ranges+1] = { tonumber(pick_parameter(lex, i, 1)),  tonumber(pick_parameter(lex, i, 2)) }
      end
      if #ranges > 0 then
	 if is_w[t] then
	    ranges[#ranges].w = true
	 end
	 if is_r[t] then
	    ranges[#ranges].r = true
	 end
	 if has_m[t] then
	    local m1 = pick_parameter(lex, i, 6) or pick_parameter(lex, i, 5) or pick_parameter(lex, i, 4) or pick_parameter(lex, i, 3) or pick_parameter(lex, i, 2)
	    if m1 then
	       ranges[#ranges].mask = tonumber(m1)
	    end
	 end
      end
      i = i + 1
   end

end
