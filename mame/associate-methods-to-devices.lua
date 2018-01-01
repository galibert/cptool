dofile("lib.lua")

--load_devlist("devices-in-drivers.txt")

function mth_add(mthmap, method, map, mapclass)
   if not mthmap[method] then
      mthmap[method] = { { map = map, mapclass = mapclass } }
   else
      local mm = mthmap[method]
      for i=1,#mm do
	 if mm[i].map == map then
	    return
	 end
      end
      mm[#mm+1] = { map = map, mapclass = mapclass }
   end
end

function retrieve_devices_class_tags(cpumap, imports, mth, mc)
   function add_to_result(r, class, tag)
      for i = 1,#r do
	 if r[i].class == class and r[i].tag == tag then
	    return
	 end
      end
      r[#r+1] = { class = class, tag = tag }
   end

   local r = {}
   
   for i=1,#mc do
      local map = mc[i].map
      local mapclass = mc[i].mapclass

      if not map then
	 if mth:sub(1,3) == "esd" then
	    mapclass = "esd16_state"
	    map = "multchmp_map"
	 end
	 if mth:sub(1,9) == "tc0180vcu" then
	    mapclass = "taitob_state"
	    map = "rastsag2_map"
	 end
      end
      if cpumap[map] then
	 add_to_result(r, mapclass, cpumap[map].cpu)
      elseif imports[map] then
	 local r1 = retrieve_devices_class_tags(cpumap, imports, mth, imports[map])
	 for j=1,#r1 do
	    r[#r+1] = r1[j]
	 end
      else
	 print(string.format("Missing map mcfg for method %s on map %s of driver %s", mth, map, mapclass))
      end
   end

   return r
end

files = filter_files(cp.scan(arg[1] .. "/src/mame/drivers"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

for j=1,#files do
   local f = io.open(files[j], "rb")
   local s = f:read("*all")
   f:close()

   local lex = cp.parse(s)

   local cpumap = {}
   local mthmap = {}
   local imports = {}
   local cur_map
   local cur_mapclass
   local mcfg_name, cpu_tag, map_name
   local in_dam = false

   for i=1,#lex do
      local t = lex[i].token
      if t == "MACHINE_CONFIG_START" then
	 mcfg_name = pick_parameter(lex, i, 1)
      end
      if t == "MCFG_CPU_ADD" or t == "MCFG_CPU_MODIFY" then
	 cpu_tag = pick_parameter(lex, i, 1)
      end
      if t == "MCFG_CPU_PROGRAM_MAP" or t == "MCFG_DEVICE_PROGRAM_MAP" or
	 t == "MCFG_CPU_DATA_MAP" or t == "MCFG_DEVICE_DATA_MAP" or
	 t == "MCFG_CPU_IO_MAP" or t == "MCFG_CPU_IO16_MAP" or t == "MCFG_DEVICE_IO_MAP" or
	 t == "MCFG_CPU_DECRYPTED_OPCODES_MAP" or t == "MCFG_DEVICE_DECRYPTED_OPCODES_MAP" or 
	 t == "MCFG_I4004_ROM_MAP" or
	 t == "MCFG_I4004_RAM_MEMORY_MAP" or
	 t == "MCFG_I4004_ROM_PORTS_MAP" or
	 t == "MCFG_I4004_RAM_STATUS_MAP" or
	 t == "MCFG_I4004_RAM_PORTS_MAP" or
	 t == "MCFG_I4004_PROGRAM_MEMORY_MAP" or
	 t == "MCFG_I8086_STACK_MAP" or
	 t == "MCFG_I8086_CODE_MAP" or
	 t == "MCFG_I8086_EXTRA_MAP"
      then
	 map_name = pick_parameter(lex, i, 1)
	 if map_name then
	    cpumap[map_name] = { mcfg = mcfg_name, cpu = cpu_tag }
	 end
      end
      if t == "MCFG_DEVICE_ADDRESS_MAP" or t == "MCFG_CPU_ADDRESS_MAP" or t == "MCFG_GT64XXX_SET_CS" or t == "MCFG_PCI9050_SET_MAP" or t == "MCFG_VRC5074_SET_CS" then
	 map_name = pick_parameter(lex, i, 2)
	 if map_name then
	    cpumap[map_name] = { mcfg = mcfg_name, cpu = cpu_tag }
	 end
      end
      if t == "MCFG_ABC1600_MAC_ADD" then
	 cpumap[pick_parameter(lex, i, 2)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
      end
      if t == "MCFG_MOS7360_ADD" then
	 cpumap[pick_parameter(lex, i, 5)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
      end
      if t == "MCFG_TMS99xx_ADD" or t == "MCFG_MOS656X_ATTACK_UFO_ADD" or t == "MCFG_MOS6560_ADD" then
	 cpumap[pick_parameter(lex, i, 4)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
	 cpumap[pick_parameter(lex, i, 5)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
      end
      if t == "MCFG_DAVE_ADD" then
	 cpumap[pick_parameter(lex, i, 3)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
	 cpumap[pick_parameter(lex, i, 4)] = { mcfg = mcfg_name, cpu = pick_parameter(lex, i, 1) }
      end
      if t == "ADDRESS_MAP_START" then
	 cur_map = pick_parameter(lex, i, 1)
	 cur_mapclass = pick_parameter(lex, i, 4)
	 in_dam = false
      end
      if t == "DEVICE_ADDRESS_MAP_START" then
	 in_dam = true
      end
      if t == "AM_READ" or t == "AM_WRITE" or t == "AM_READ8" or t == "AM_WRITE8" or t == "AM_READ16" or t == "AM_WRITE16" or t == "AM_READ32" or t == "AM_WRITE32" then
	 if not in_dam then
	    mth_add(mthmap, pick_parameter(lex, i, 1), cur_map, cur_mapclass)
	 end
      end
      if t == "AM_READWRITE" or t == "AM_READWRITE8" or t == "AM_READWRITE16" or t == "AM_READWRITE32" then
	 if not in_dam then
	    mth_add(mthmap, pick_parameter(lex, i, 1), cur_map, cur_mapclass)
	    mth_add(mthmap, pick_parameter(lex, i, 2), cur_map, cur_mapclass)
	 end
      end
      if t == "AM_IMPORT_FROM" then
	 if not in_dam then
	    mth_add(imports, pick_parameter(lex, i, 1), cur_map, cur_mapclass)
	 end
      end
   end

   for mth, mc in pairs(mthmap) do
      local devs = retrieve_devices_class_tags(cpumap, imports, mth, mc)

      for i=1,#devs do
	 print(string.format("%s %s %s", devs[i].class, mth, devs[i].tag))
      end
   end
end
