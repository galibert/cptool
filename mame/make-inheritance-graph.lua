dofile("lib.lua")

files = filter_files(cp.scan(arg[1] .. "/src"), { ".cpp", ".hxx", ".c", ".h", ".hpp" })

for fi=1,#files do
   f = io.open(files[fi], "rb")
   s = f:read("*all")
   f:close()

   lex = cp.parse(s)

   for i=1, #lex do
      local t = lex[i].token 
      if (t == "class" or t == "struct") and lex[i+2].token == ":" then
	 local cln = lex[i+1].token
	 local parents = {}
	 local j = i+3
	 while lex[j].token ~= "" and lex[j].token ~= "{" and lex[j].token ~= ";" and lex[j].token ~= "#" and lex[j].token ~= "<" do
	    local t1 = lex[j].token
	    if t1 ~= "private" and t1 ~= "protected" and t1 ~= "public" and t1 ~= "," and t1:sub(1, 2) ~= "//" and t1:sub(1, 2) ~= "/*" then
	       while lex[j+1].token == "::" do
		  t1 = t1 .. lex[j+1].token .. lex[j+2].token
		  j = j + 2
	       end
	       parents[#parents+1] = t1
	    end
	    j = j + 1
	 end
	 if lex[j].token == "{" and #parents > 0 then
	    io.write(cln)
	    for j=1,#parents do
	       io.write(" " .. parents[j])
	    end
	    io.write("\n")
	 end
      end
   end
end

