local prototype = require "prototype"

---------------------------------------------------------------------------------
--                               Packs
--
-- pack — simple integer indexed table to handle varargs and sequences
--
---------------------------------------------------------------------------------

local Pack = {}

--
-- creates a pack from vararg
--
function Pack:new (...)
    local obj = table.pack(...)
    setmetatable(obj, self)
    self.__index = self
    return obj
end

--
-- adds value to the end of a pack
-- 
function Pack:push (value)
    self.n = self.n + 1
    self[self.n] = value
end

--
-- removes pack's last value from the table
--
function Pack:pop ()
    assert(self.n > 0, "pop from empty pack")
    self.n = self.n - 1
    return table.remove(self, self.n + 1)
end

--
-- returns pack's size
--
function Pack:__len ()
    return self.n
end

--
-- generator for Pack:ipairs()
--
function Pack:iterator (i)
    i = (i or 0) + 1
    if i <= #self then
        return i, self[i]
    end
end

--
-- sequence of pack values
--
function Pack:ipairs()
    return Pack.iterator, self, nil
end

--
-- concatenates two packs together
--
function Pack:__concat (pack)
    assert(prototype.instanceof(pack, Pack), "expected pack for concatenation")
    local cat = Pack:new()
    for _, t in ipairs({self, pack}) do
        for _, v in t:ipairs() do
            cat:push(v)
        end
    end
    return cat
end

local function range_check(start, last, i)
    assert(start <= i and i <= last, string.format("index: %d out of range: [%d, %d]", i, start, last))
end

function Pack:slice (i, j)
	i = i or 0
    j = j or #self
	range_check(0, #self, i)
	range_check(0, #self, j)
	local r = Pack:new()
	for k = i + 1, j do
		r:push(self[k])
	end
	return r
end

function Pack:splice (i, j)
	i = i or 0
	j = j or #self
	local r = self:slice(i, j)
	for k = i + 1, j do
	    self[k] = self[k + j - i]
    end	
	self.n = self.n - j + i
	return r
end

local function pack (...) 
    return Pack:new(...)
end

return {
    pack = pack
}
