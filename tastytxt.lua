--[[A small collection of lua snippets to work with multilingual text]]
local tastytxt = {}

utf8 = require 'lua-utf8'
--tds = require 'tds' --https://github.com/torch/tds
--pretty = require 'pl.pretty'

-- if a dir contains files, return an array of file full paths
function tastytxt.ls(path)
    local i,files = 0,{}
    local pfile = io.popen('ls "'..path..'"')
    for fname in pfile:lines() do
        i = i + 1
        -- path must end on / or \
        fpath = path..fname
        files[i] = fpath
    end
    pfile:close()
    return files
end


-- read corpus file
function tastytxt.read(fname)
  local ifile = assert(io.open(fname, 'r'))
  local fdata = ifile:read("*all")
  ifile:close()
  return fdata
end

function tastytxt.write(text,fname)
  local text = text
  local ofile = fname
  -- write file
  ofile = assert(io.open(fname,'w'))
  ofile:write(text)
  ofile:close()
  return true
end

-- lowercase all text in a file
function tastytxt.low(text)
  local text = text
  return utf8.lower(text)
end

-- separate punctuation from text
function tastytxt.tokpunct(text)
  local text = text
  local new_text = ''
  local loops = 0
  -- iterate over each line, otherwise we are breaking text formatting
  for line in utf8.gmatch(text,"[^\n]+") do
    -- surround punctuation with spaces
    line = utf8.gsub(line,"(%p)"," %1 ")
    -- replace mult space with single space
    line = utf8.gsub(line,"%s%s+"," ")
    -- fix 's
    line = utf8.gsub(line," ' s "," 's ") -- for English
    new_text = new_text..line.."\n"
    loops = loops + 1
    if loops % 10000 == 0 then collectgarbage() end
  end
  return new_text
end

-- count the number of tokens using str match
function tastytxt.tokcnt(text)
  local text = text
  local _,cnt = utf8.gsub(text,"%S+","")
  return cnt
end

-- strip punctuation
function tastytxt.stripp(text)
  local text = text
  local new_text = ''
  local loops = 0
  -- iterate over each line, otherwise we are breaking text formatting
  for line in utf8.gmatch(text,"[^\n]+") do
    line = utf8.gsub(line,"%p",' ')
    -- replace mult space with single space
    line = utf8.gsub(line,"%s%s+"," ")
    new_text = new_text..line.."\n"
    loops = loops + 1
    if loops % 10000 == 0 then collectgarbage() end
  end
  return new_text
end

-- refit corpus so that each sentence takes one line
--[[
function tastytxt.sent2line(text)
  local text = text
  local sents = {}
  for sent in utf8.gmatch(text, "[^%.%?%!]+[%.%!%?]+") do
    print(sent)
    print('-----')
  end
end
]]

-- tokenize text and return lines array of tokens array
function tastytxt.tok(text)
  local text = text
  local lines = {}
  local toks = {}
  -- split by lines
  for line in utf8.gmatch(text,"[^\n]+") do
    toks = {}
    -- split each line by tokens
    for word in utf8.gmatch(line,"%S+") do
      table.insert(toks,word)
    end
    table.insert(lines,toks)
  end
  return lines
end

-- count token occurences and return the token,occurences map
function tastytxt.tokmap(text)
  local text = text
  local wordmap = {}
  -- count tokens
  for word in utf8.gmatch(text,"%S+") do
    if wordmap[word] then
      wordmap[word] = wordmap[word] + 1
    else
      wordmap[word] = 1
    end
  end
  return wordmap
end

-- return tokens occurring <= max number of times
function tastytxt.rare(text,max)
  -- count tokens
  local wordmap = tastytxt.tokmap(text)
  -- find singletons
  local singletons = {}
  for k,v in next,wordmap,nil do
    if v <= max then
      table.insert(singletons,k)
    end
  end
  --pretty.dump(singletons)
  return singletons
end

-- return vocabulary of text and its cnt
function tastytxt.vocab(text)
  local text = text
  local vocab = {}
  local cnt = 0
  for token in utf8.gmatch(text,"%S+") do
    if vocab[token] == nil then
      vocab[token] = true
      cnt = cnt + 1
    end
  end
  return vocab,cnt
end

-- replace a digit with 0
function tastytxt.dig2zero(text)
  local text = text
  return utf8.gsub(text,"%d","0")
end

-- replace cnt-frequency tokens with <unk>
function tastytxt.repunk(text,cnt)
  local text = text
  -- find rare tokens
  local rare = tastytxt.rare(text,cnt)
  -- tokenize text and return tokens array
  text_arr = tastytxt.tok(text)
  -- convert to datatype independent from Lua memory allocator, helps with not enough memory errors
  --text_arr = tds.Hash(text_arr)
  -- replace rare tokens with <unk>
  for l=1,#text_arr do -- iterating lines {}
    for t=1,#text_arr[l] do -- iterating tokens {}
      for r=1,#rare do
        if text_arr[l][t] == rare[r] then text_arr[l][t] = "<unk>" end
      end
    end
  end
  -- merge text array back
  text = ""
  local line = ""
  local loops = 0
  for l=1,#text_arr do -- iterating lines {}
    line = ""
    for t=1,#text_arr[l] do -- iterating tokens {}
      line = line.." "..text_arr[l][t]
    end
    text = text..utf8.gsub(line," ","",1).."\n" -- remove leading space, add newline
    loops = loops + 1
    if loops % 10000 == 0 then collectgarbage() end
  end
  return text
end

--[[Do complete preprocessing of a corpus which includes:
lowecasing, tokenization, replacing rare (singleton) tokens with <unk>, replacing
digits with zeros. Include an option to include/exclude punctuation and <unk>.

incpunct -- include punctuation if true
incunk -- include <unk> if true
]]
function tastytxt.prep(text,punct,unk)
  local text = text
  -- lowercase text
  print('> lowercasing...')
  text = tastytxt.low(text)
  if punct == 'nopunkt' then print('> stripping punctuation...') text = tastytxt.stripp(text) end
  -- tokenize punctuation
  print('> tokenizing...')
  text = tastytxt.tokpunct(text)
  -- replace digits with zeros
  print('> digits to zero...')
  text = tastytxt.dig2zero(text)
  -- replace singletons with <unk>
  if unk == 'unk' then print('> adding <unk>...') text = tastytxt.repunk(text,1) end
  return text
end

-- if a table contains only str keys {token:cnt}, count the number of str keys
function tastytxt.countstrkeys(table)
    local keycnt = 0
    for key,val in next,table do
        keycnt = keycnt + 1
    end
    return keycnt
end

return tastytxt