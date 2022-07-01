local pack = require "pack"
local pack = pack.pack
---------------------------------------------------------------------------------------------------
--                               Sequences and Generators
--
--   generator — a pure function, which takes target, state and produces new_state, value.
--     if generator's new_state is nil, then it is treated as exhausted
--
--   sequence — a triple of generator, gen_target, gen_state
--     sequence is empty if gen = target = state = nil
--     is_empty(rest(seq)) => first(seq) == nil
--
--   first(empty) == nil
--   rest(empty) == empty
--   step(empty) == nil, empty
--
---------------------------------------------------------------------------------------------------

local function call_if_not_nil(func, ...)
	if func ~= nil then 
		return func(...)
	end
end

local seq = {
    unpacked = {},
	packed = {},
	unpack = function (seq)
		seq = seq or {}
	    return table.unpack(seq, 1, 3) 
	end,
	pack = pack
}

function seq_function (config, body)
	config.default = config.default or 'packed'
	local fname, fbody
	for k, v in pairs(config) do
		if k ~= 'default' and k ~= 'tails_seq' then
		    fname, fbody = k, v
		end
	end
	
	assert(fname ~= nil and type(fbody) == 'function', "Syntax: function not found")
	
	seq.unpacked[fname] = fbody
	
	local function expand (...)
		local args = pack(...)
		local seq = pack(seq.unpack(args:pop()))			
		return table.unpack(args .. seq)
	end
	
	if config.tails_seq then 
	    seq.packed[fname] = function (...)
		    local result = pack(seq.unpacked[fname](expand(...)))
			local seq = result:splice(#result - 3)
			result:push(seq)
			return table.unpack(result)
		end
	else
	    seq.packed[fname] = function (...)
		    return seq.unpacked[fname](expand(...))
		end
	end
	seq[fname] = seq[config.default][fname]
end

--
-- checks whether the sequence is empty
--
seq_function({
    is_empty = function (gen, target, state)
	    return gen == nil and target == nil and state == nil
    end
})

--
-- checks whether the sequence is not empty
--
seq_function({
    not_empty = function (gen, target, state)
	    return not seq.unpacked.is_empty(gen, target, state)
    end
})

-- 
-- makes one step in a sequence returning value, [gen, target, state]
--
seq_function({
	tails_seq = true,
	step = function (gen, target, state)
        if seq.unpacked.not_empty(gen, target, state) then 
            local state, value = gen(target, state)
			if state == nil then
			    return nil, nil, nil, nil
			end
            return value, gen, target, state
        end
	    return nil, gen, target, state
    end
})

--
-- returns first element from a sequence
--
seq_function({
	first = function (gen, target, state)
        local v = seq.unpacked.step(gen, target, state)
        return v
    end
})

--
-- returns rest of a sequence
--
seq_function({
	tails_seq = true,
	rest = function (gen, target, state)
        local _, gen, target, state = seq.unpacked.step(gen, target, state)
        return gen, target, state
    end
})

seq_function({
    tails_seq = true,
	cons = function (v, gen, target, state)
		local state = {consed = pack(state), value = v}
		return function (target, state)
		    if type(state) == 'table' and state.consed then 
				return {current = state.consed}, state.value
			end
			if type(state) == 'table' and state.current then 
			    return call_if_not_nil(gen, target, state.current[1])
			end
			return call_if_not_nil(gen, target, state)
		end,
		target, 
		state
	end
})

--
-- takes first n elements as a pack, returns pack and rest of a sequence
--
seq_function({
	tails_seq = true,
	take_n = function (n, gen, target, state)
        local result, v = pack(), nil
        while seq.unpacked.not_empty(gen, target, state) and n > 0 do
		    v, gen, target, state = seq.unpacked.step(gen, target, state)
		    if seq.unpacked.not_empty(gen, target, state) then
                result:push(v)
	    	end
            n = n - 1
        end
        return result, gen, target, state
    end
})

--
-- takes whole sequence as a pack 
--
seq_function({
	take = function (gen, target, state)
        local result, v = pack(), nil
        while seq.unpacked.not_empty(gen, target, state) do 
	        v, gen, target, state = seq.unpacked.step(gen, target, state)
		    if seq.unpacked.not_empty(gen, target, state) then
                result:push(v)
		    end
        end
        return result
    end
})

--
-- returns two packs made from sequence: (first n elements), (rest)
--
seq_function({
	slice = function (n, gen, target, state)
        local p, gen, target, state = seq.unpacked.take_n(n, gen, target, state)
        local r = seq.unpacked.take(gen, target, state)
        return p, r
    end
})

--
-- drops first n elements
--
seq_function({
	tails_seq = true,
	drop = function (n, gen, target, state)
        if n <= 0 or seq.unpacked.is_empty(gen, target, state) then
		    return gen, target, state
	    end
        return seq.unpacked.drop(n - 1, unpacked.rest(gen, target, state))
    end
})

--
-- applies function to each value
--
seq_function({
	tails_seq = true,
	map = function (func, gen, target, state)
        return function(target, state)
	        local v, gen, target, state = seq.unpacked.step(gen, target, state)
		    if seq.unpacked.not_empty(gen, target, state) then
                return state, func(v, state, target)
		    end
        end,
        target, state
    end
})


--
-- reduces sequence with function
--
seq_function({
	reduce = function (func, acc, gen, target, state)
        if seq.unpacked.is_empty(gen, target, state) then
	        return acc
	    end
	    v, gen, target, state = seq.unpacked.step(gen, target, state)
		if seq.unpacked.is_empty(gen, target, state) then 
			return acc
		end
	    return seq.unpacked.reduce(func, func(acc, v), gen, target, state)
    end
})

return seq