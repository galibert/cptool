dofile("lib.lua")

inheritance_load("inheritance.txt")

classes = list_derivatives_of("driver_device")

is_interesting = {}

for i=1,#classes do
   is_interesting[classes[i]] = true
end

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

function set(reg, class, var, field, val)
   if not reg[class] then reg[class] = {} end
   if not reg[class][var] then reg[class][var] = {} end
   reg[class][var][field] = val
end

function scan_constructor_init(lex, i, cln, reg)
   while lex[i].token ~= ")" do
      i = i + 1
   end
   i = i + 1
   if lex[i].token ~= ";" then
      while lex[i].token ~= "{" do
	 if lmatch(lex, i+1, { "(", "*", "this", "," }) and lex[i+6].token == ")" then
	    local name = lex[i+5].token
	    set(reg, cln, lex[i].token, "name", name)
	    i = i + 7
	 else
	    while(lex[i].token ~= ")") do
	       i = i + 1
	    end
	    i = i + 1
	 end
	 if lex[i].token ~= "," then
	    return
	 end
	 i = i + 1
      end
   end
end

function scan_class_interface(lex, i, cln, reg)
   local ad = 0
   while true do
      local t = lex[i].token
      if t == "{" then
	 ad = ad + 1
      end
      if t == "}" then
	 ad = ad - 1
	 if ad == 0 then
	    return
	 end
      end
      if t == cln and lex[i-1].token ~= "~" and lex[i+1].token == "(" then
	 scan_constructor_init(lex, i, cln, reg)
      end
      if t == "required_device" or t == "optional_device" then
	 local t = lex[i+2].token
	 local name = lex[i+4].token
	 set(reg, cln, name, "type", t)
      end
      i = i + 1
   end
end

local reg = {}

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   for i=1, #lex do
      local t = lex[i].token 
      if (t == "class" or t == "struct") and lex[i+2].token == ":" then
	 local cln = lex[i+1].token
	 if is_interesting[cln] then
	    while lex[i].token ~= "{" and lex[i].token ~= ";" do
	       i = i + 1
	    end
	    if lex[i].token == "{" then
	       scan_class_interface(lex, i, cln, reg)
	    end
	 end
      end
      if t == "::" and is_interesting[lex[i+1].token] and lex[i-1].token == lex[i+1].token and lex[i+2].token == "(" then
	 scan_constructor_init(lex, i, lex[i+1].token, reg)
      end
   end
end

for class,v1 in pairs(reg) do
   for var, r in pairs(v1) do
      if r.name and r.type then
	 print(string.format("%s %s %s %s", class, var, r.type, r.name))
      end
   end
end
