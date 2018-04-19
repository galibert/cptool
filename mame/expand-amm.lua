local am_infos = {}
for l in io.lines("am-infos-all.txt") do
   local meth, dw, aw, as, en = l:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
   dw = tonumber(dw)
   aw = tonumber(aw)
   as = tonumber(as)
   en = tonumber(en)
   am_infos[meth] = { dw=dw, aw=aw, as=as, en=en }
end

for l in io.lines("address-maps-mappings.txt") do
   local meth, dw, rmeth = l:match("(%S+) (%S+) (%S+)")
   if am_infos[meth] then
      local a = am_infos[meth]
      if dw == "0" then
	 dw = a.dw
      end
      print(string.format("%s %d %d %d %d",
			  rmeth,
			  dw,
			  a.aw, a.as, a.en))
   end
end
