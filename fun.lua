local seq = require "seq"

local pack = require "pack"
pack = pack.pack

local fun = {}

--
-- function composition
--
function fun.compose (...)
    local p = pack(...)
    return function (...)
        local result = nil
        for i, v in p:ipairs() do
            if i == 1 then 
                result = v(...)
            else
                result = v(result)
            end
        end
        return result
    end
end

--
-- unpacks sequence at the end
--
function fun.apply(func, ...) 
    local args = pack(...)
	local s = args:pop()
    return func(table.unpack(args .. seq.take(s)))
end

--
-- general func for partial_last and partial
--
local function get_partial_slice (calc_slice_point)
    return function (offset)
        assert(offset >= 0, "offset must be non negative integer")
        return function (func, ...)
            local mid = pack(...)
            return function (...)
                local args = pack(...)
                local l, r = seq.slice(calc_slice_point(offset, args, mid), args:ipairs())
                return func(table.unpack(l .. mid .. r))
            end
        end
    end    
end

local function partial_general (calc_offset)
    local partial_offset = get_partial_slice(calc_offset)
    return function (func, ...)
        local n = select('#', ...)
        if n == 0 and type(func) == 'number' then
            return partial_offset(func)
        end
		assert(n > 0, "at least one argument must be fixed by partial")
        return partial_offset(0)(func, ...)
    end
end

--
-- returns function's partial application with arguments fixed at the beginning
--   offset for args can be provided if partial is called with one integer argument
--
-- examples: 
--   partial(print, 1, 2, 3)(4, 5) equialent to partial(0)(print, 1, 2, 3)(4, 5)
--   > 1 2 3 4 5
--   partial(2)(print, 3, 4, 5)(1, 2, 6)
--   > 1 2 3 4 5 6
--
fun.partial = partial_general(function (offset) return offset end)
fun.back_partial = partial_general(function (offset, args) return #args - offset end)

return fun
