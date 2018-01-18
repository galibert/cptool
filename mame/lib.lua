function range_rebuild(lex, idxs, idxe)
   local r = ""
   for i = idxs,idxe-1 do
      if i ~= idxs then
	 r = r .. lex[i].ws
      end
      r = r .. lex[i].token
   end
   return r
end

function skip_parameter(lex, idx)
   local pc = 0
   while pc ~= 0 or (lex[idx].token ~= "," and lex[idx].token ~= ")") do
      if lex[idx].token == "" then
	 return nil
      end
      if lex[idx].token == "(" or lex[idx].token == "{" or lex[idx].token == "["  then
	 pc = pc + 1
      elseif lex[idx].token == ")" or lex[idx].token == "}" or lex[idx].token == "]" then
	 pc = pc - 1
      end
      idx = idx + 1
   end
   return idx
end

function pick_parameter(lex, idx, number)
   if lex[idx+1].token ~= "(" then
      return nil
   end
   idx = idx + 2
   while number ~= 1 do
      idx = skip_parameter(lex, idx)
      if not idx or lex[idx].token == ")" then
	 return nil
      end
      idx = idx + 1
      number = number - 1
   end

   local idxe = skip_parameter(lex, idx)
   if not idxe then
      return nil
   end

   return range_rebuild(lex, idx, idxe)
end

function set_parameter(lex, idx, number, text)
   if lex[idx+1].token ~= "(" then
      return false
   end
   idx = idx + 2
   while number ~= 1 do
      idx = skip_parameter(lex, idx)
      if not idx then
	 return false
      end
      idx = idx + 1
      number = number - 1
   end

   local idxe = skip_parameter(lex, idx)
   if not idxe then
      return false
   end

   lex:replace(idx, idxe-1, text)
   return true
end

function unstring(str)
   local i1, i2
   for i=1,#str do
      if str:sub(i, i) == "\"" then
	 if not i1 then i1 = i end
	 i2 = i
      end
   end
   if i1 and i2 then
      return str:sub(i1+1, i2-1)
   else
      return str
   end
end

function filter_files(list, extensions)
   local r = {}
   for i=1, #list do
      local f = list[i]
      local l = f:len()
      for j=1,#extensions do
	 local e = extensions[j]
	 if f:sub(l + 1 - e:len()) == e then
	    r[#r+1] = f
	    break
	 end
      end
   end
   return r
end

inheritance_info = {}
inheritance_info_i = {}
function inheritance_load(file)
   local f = io.open(file, "r")
   for l in f:lines() do
      local classes = {}
      local clbase
      for class in l:gmatch("%S+") do
	 if clbase then
	    if not inheritance_info_i[class] then
	       inheritance_info_i[class] = {}
	    end
	    inheritance_info_i[class][#inheritance_info_i[class]+1] = clbase
	    classes[#classes+1] = class
	 else
	    clbase = class
	 end
      end
      inheritance_info[clbase] = classes
   end
end

function inherits_from(class, parent)
   local p = inheritance_info[class]
   if p then
      for i=1, #p do
	 if p[i] == parent or inherits_from(p[i], parent) then
	    return true
	 end
      end
   end
   return false
end

function list_derivatives_of(class)
   local r = {}
   for c, l in pairs(inheritance_info) do
      local hit = false
      for i=1,#l do
	 if not hit and (l[i] == class or inherits_from(l[i], class)) then
	    hit = true
	 end
      end
      if hit then
	 r[#r+1] = c
      end
   end
   return r
end

function lmatch(lex, index, tokens)
   for i=1,#tokens do
      if tokens[i] ~= "" and lex[index+i-1].token ~= tokens[i] then
	 return false
      end
   end
   return true
end

function make_hash(l)
   local h = {}
   for i=1,#l do
      h[l[i]] = true
   end
   return h
end
