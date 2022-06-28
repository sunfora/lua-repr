--
-- Checks whether the table has prototype in its prototype-chain
--
local function instanceof (table, prototype)
    while table do
        if table == prototype then 
            return true
        end
        table = getmetatable(table)
    end
    return false
end

---------------------------------------------------------------------------------
--                               Packs
--
-- pack — simple indexed table to handle varargs and sequences
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
    assert(instanceof(pack, Pack), "expected pack for concatenation")
    local cat = Pack:new()
    for _, t in ipairs({self, pack}) do
        for _, v in t:ipairs() do
            cat:push(v)
        end
    end
    return cat
end

local function pack (...) 
    return Pack:new(...)
end

---------------------------------------------------------------------------------------------------
--                               Sequences and Generators
--
--   generator — a pure function, which takes target, state and produces new_state, value.
--     if generator's new_state is nil, then it is treated as exhausted
--
--   sequence — a triple of generator, gen_target, gen_state
--     sequence is empty if generator is nil
--
---------------------------------------------------------------------------------------------------

--
-- calls a function if not nil
--
local function call_if_not_nil (func, ...)
    if func ~= nil then
        return func(...)
    end
end

--
-- checks whether the sequence has more items 
--
local function has_next (gen, target, state)
    local state = call_if_not_nil(gen, target, state)
    return state ~= nil
end

--
-- checks whether the sequence is empty
--
local function is_empty (gen, target, state)
    return gen == nil
end

-- 
-- makes one step in a sequence returning value, gen, target, state
--
local function step (gen, target, state)
    if not is_empty(gen, target, state) then 
        local state, value = gen(target, state)
        if state == nil then 
            return value
        end
        return value, gen, target, state            
    end
end

--
-- returns first element from a sequence
--
local function first (gen, target, state)
    local v = step(gen, target, state)
    return v
end

--
-- returns rest of a sequence
--
local function rest (gen, target, state)
    local _, gen, target, state = step(gen, target, state)
    if not is_empty(gen, target, state) then 
        return gen, target, state
    end
end


--
-- takes first n elements as a pack, returns pack and rest of sequence
--
local function take_n (n, gen, target, state) 
    local result = pack()
    while has_next(gen, target, state) and n > 0 do
        result:push(first(gen, target, state))
        gen, target, state = rest(gen, target, state)
        n = n - 1
    end
    return result, gen, target, state
end

--
-- takes whole sequence as a pack 
--
local function take (gen, target, state)
    local result = pack()
    while has_next(gen, target, state) do 
        result:push(first(gen, target, state))
        gen, target, state = rest(gen, target, state)
    end
    return result
end

--
-- returns two packs made from sequence: (first n elements), (rest)
--
local function slice (n, gen, target, state)
    local p, gen, target, state = take_n(n, gen, target, state)
    local r = take(gen, target, state)
    return p, r
end

--
-- drops first n elements
--
local function drop (n, gen, target, state)
    while n > 0 and has_next(gen, target, state) do 
        gen, target, state = rest(gen, target, state)
        n = n - 1
    end
    return gen, target, state
end

--
-- applies function to each value
--
local function map (func, gen, target, state)
    return function(target, state)
        if has_next(gen, target, state) then
            local state, v = gen(target, state)
            return state, func(v, state, target)
        end
    end,
    target, state
end

--------------------------------------------------------
--                   Functional
--------------------------------------------------------

-- 
-- if flag is set to true, runs func with arguments
--
local function ignore_if_not(flag, func, ...)
    if flag then 
        return func(...)
    end
end

--
-- function composition
--
local function compose (...)
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
local function apply(func, ...) 
    local args = pack(...)
    local state = args:pop()
    local target = args:pop()
    local gen = args:pop()
    return func(table.unpack(args .. take(gen, target, state)))
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
                local l, r = slice(calc_slice_point(offset, args, mid), args:ipairs())
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
        elseif n == 0 then
        end
        return partial_offset(0)(func, ...)
    end
end

--
-- returns function with partial application with arguments fixed at the beginning
--   offset for args can be provided if partial is called with one integer argument
--
-- examples: 
--   partial(print, 1, 2, 3)(4, 5) equialent to partial(0)(print, 1, 2, 3)(4, 5)
--   > 1 2 3 4 5
--   partial(2)(print, 3, 4, 5)(1, 2, 6)
--   > 1 2 3 4 5 6
--
local partial = partial_general(function (offset) return offset end)
local back_partial = partial_general(function (offset, args) return #args - offset end)

------------------------------------------------------------------------------------
--                                Packs
------------------------------------------------------------------------------------

--
-- pretty print for packs
--
function Pack:__tostring ()
    return '[' .. table.concat(take(map(tostring, self:ipairs())), ', ') .. ']'
end

------------------------------------------------------------------------------------
--                          Representations 
------------------------------------------------------------------------------------

--
-- Forms a subconfig with all the keys from @keys,
-- and values from @table first, or defaults from @keys
--
function subconfig(tabl, conf)
    tabl = tabl or {}
    local result = {}
    for k, v in pairs(conf) do
        result[k] = (tabl[k] == nil) and v or tabl[k]
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = subconfig(result[k], v)
        end
    end
    return result
end 

--
-- concats array with separators and indentation
-- @config.sep maintains separator
-- @config.indentation maintains indentation string
-- @config.style maintains style of bracketting
-- @depth maintains indentation depth
--
local function array_format(array, config, depth)
        depth = depth or 0
        config = subconfig(config, {sep = ', ', indentation = '\t', style = '[%s]'})
        local sep = config.sep
        local ind = config.indentation
        local style = config.style
        
        if sep:sub(#sep) ~= '\n' or ind == nil then 
            return string.format(style, table.concat(array, sep))            
        end
        
        local left_indent = '\n' .. ind:rep(depth)
        local right_indent = '\n' .. ind:rep(depth - 1)
        local elem_indent = sep .. ind:rep(depth)
        
        return string.format(style, left_indent .. table.concat(array, elem_indent) .. right_indent)
end

local function rawtostring(tab)
    if debug.getmetatable(tab) and debug.getmetatable(tab).__tostring then
        local meta = debug.getmetatable(tab)
        debug.setmetatable(tab, nil)
        local res = tostring(tab)
        debug.setmetatable(tab, meta)
        return res
    end
    return tostring(tab)
end

--
-- default configs for representations
--
local represent = {
    table = {},
    string = {},
    config = {
        string = {
            style = [["%s"]]
        },
        table = {
            show_address = false,
            show_metatable = false,
            content = {
                style = "{%s}",
                sep = ', ',
                indentation = '\t'
            },
            pair = {
                style = '[%s] = %s'
            },
            circular_reference = {
                style = "{%s}",
                substitution = "...",
                sep = ' ',
                indentation = '\t'
            },
            meta_info = {
                style = '((%s))',
                sep = ', ',
                indentation = '\t'
            }
        }
    }
}

represent.table.NEAT = {
    content = {
        sep = ',\n'
    }, 
    circular_reference = {
        sep = ' '
    }
}

represent.table.VERBOSE = {
    show_address = true,
    show_metatable = true,
    content = {
        sep = ',\n'
    }, 
    circular_reference = {
        sep = '\n'
    },
    meta_info = {
        sep = '\n'
    }
}

local function configured_repr (config)
    config = subconfig(config, represent.config)
    local function repr (object, ...)
        local represent_type = represent[type(object)]
        if represent_type then 
            return represent_type.as(object, config[type(object)], repr, ...)
        end
        return tostring(object)
    end
    return repr
end

--
-- returns object's representation
--
local function repr(object, config)
    return configured_repr(config)(object)
end

--
-- represents a string with quotes
-- TODO: add support for escape sequences
--
function represent.string.as(str, config, repr)
    return string.format(config.style, str)
end

--
-- makes a DFS on table, tracks circular references via @on_path and indent content with @depth param
--
function represent.table.as(tab, config, repr, on_path, depth)
    on_path = on_path or {}
    depth = depth or 0
    
    local repr_with = partial(partial(1), repr, on_path)
    
    local function pair_format (v, k) 
        return apply(string.format, config.pair.style, map(repr_with(depth + 1), ipairs({k, v})))
    end
    
    local was = on_path[tab]
    on_path[tab] = true
    
    local address = pack(ignore_if_not(config.show_address, rawtostring, tab))
    local metatable = pack(ignore_if_not(not was and config.show_metatable, repr_with(depth + 2), debug.getmetatable(tab)))
    local meta_info = pack(
        ignore_if_not(
            config.show_address or config.show_metatable, 
            array_format, address .. metatable, config.meta_info, depth + 2
        )
    )

    local map_entries = was and pack(config.circular_reference.substitution) or take(map(pair_format, next, tab, nil))
    
    local use_config = was and config.circular_reference or config.content
    local result = array_format(meta_info .. map_entries, use_config, depth + 1)

    if not was then 
        on_path[tab] = nil
    end
    
    return result
end


j = {}
for i = 1, 10000 do
    local s = {}
    j[s] = {}
    local j = s
end
a = repr(j, {table = represent.table.NEAT, string = {style = [[%s]]}})
print(a)
