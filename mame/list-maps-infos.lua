dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src/mame", arg[1] .. "/src/devices"), { ".cpp" })

table.sort(files)
--files = { arg[1] .. "/src/mame/drivers/alphatro.cpp" }

comp = "cd " .. arg[1] .. "; g++ -DPTR64=1 -DNDEBUG -DCRLF=2 -DLSB_FIRST -DFLAC__NO_DLL -DNATIVE_DRC=drcbe_x64 -DLUA_COMPAT_ALL -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2 -Isrc/osd -Isrc/emu -Isrc/devices -Isrc/mame -Isrc/lib -Isrc/lib/util -Isrc/lib/netlist -Ibuild/generated/emu/layout -Ibuild/generated/mame/layout -I3rdparty -Igenerated/mame/layout -I3rdparty/libflac/include -I3rdparty/glm -I3rdparty/libjpeg -m64 -x c++ -std=c++14 -flifetime-dse=1 -E "

for fi=1,#files do
   io.stderr:write(files[fi] .. "\n")
   f = io.popen(comp .. files[fi], "r")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   local devm = {}
   for i=1, #lex do
      local t = lex[i].token 
      if lmatch(lex, i, { "void", "", "::", "", "(", "machine_config", "&", "config" }) then
         class = lex[i+1].token
	 devt = "?"
      end
      if lmatch(lex, i, { "config", ".", "device_add", "(", "this", "," }) then
	 devt = pick_parameter(lex, i+2, 3)
	 devm[pick_parameter(lex, i+2, 2)] = devt
      end
      if lmatch(lex, i, { "config", ".", "device_replace", "(", "this", "," }) then
	 devt = pick_parameter(lex, i+2, 3)
      end
      if lmatch(lex, i, { "config", ".", "device_find", "(", "this", "," }) then
	 devt = devm[pick_parameter(lex, i+2, 2)]
      end
      if lmatch(lex, i, { "dynamic_cast", "<", "device_memory_interface", "*", ">", "(", "device", ")", "->", "set_addrmap", "(" }) then
	 local mapname = lex[pos_parameter(lex, pos_parameter(lex, i+9, 2), 2)-2].token
	 if devt == "ADDRESS_MAP_BANK" then
	    local en = 0
	    local aw = 32
	    local dw = 0

	    local j = i
	    while not lmatch(lex, j, { "device", "=" }) and not lmatch(lex, j, { "}" }) do
	       if lmatch(lex, j, { "downcast", "<", "address_map_bank_device", "&", ">", "(", "*", "device", ")", "." }) then
		  if lex[j+10].token == "set_endianness" then
		     en = lex[j+12].token == "ENDIANNESS_BIG" and 1 or 0
		  end
		  if lex[j+10].token == "set_data_width" then
		     dw = lex[j+12].token
		  end
		  if lex[j+10].token == "set_addr_width" then
		     aw = lex[j+12].token
		  end
	       end
	       j = j + 1
	    end
	    print(string.format("%s::%s %s %s 0 %s", class, mapname, dw, aw, en))
	 else
	    local sid = pick_parameter(lex, i+9, 1)
	    print(string.format("%s::%s %s %s", class, mapname, devt, sid))
	 end
      end
   end
end
