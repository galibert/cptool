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
      if not idx then
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
