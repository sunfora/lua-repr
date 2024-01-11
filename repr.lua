local pack = require "pack"
pack = pack.pack

local config = require "config"
local subconfig = config.subconfig

local fun = require "fun"
local seq = require "seq"


------------------------------------------------------------------------------------
--                          Representations 
------------------------------------------------------------------------------------

-- 
-- if flag is set to true, runs func with arguments
--
local function ignore_if_not(flag, func, ...)
    if flag then 
        return func(...)
    end
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
            style = [["%s"]],
			escapes = {
	            ['\a'] = '\\a',
                ['\b'] = '\\b',
                ['\f'] = '\\f',
                ['\n'] = '\\n',
                ['\r'] = '\\r',
                ['\t'] = '\\t',
                ['\v'] = '\\v'
            }
        },
        table = {
            show_address = false,
            show_metatable = false,
            content = {
                style = "{%s}",
                sep = ', ',
                indentation = '  '
            },
            pair = {
                style = '[%s] = %s'
            },
            circular_reference = {
                style = "{%s}",
                substitution = "...",
                sep = ' ',
                indentation = '  '
            },
            meta_info = {
                style = '((%s))',
                sep = ', ',
                indentation = '  '
            }
        }
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
-- represents string with quotes
--
function represent.string.as(str, config, repr)
	for k, v in pairs(config.escapes) do
		str = str:gsub(k, v)
	end
    return string.format(config.style, str)
end

--
-- makes a DFS on table, tracks circular references via @on_path and indent content with @depth param
--
function represent.table.as(tab, config, repr, on_path, depth)
    on_path = on_path or {}
    depth = depth or 0
    
    local repr_with = fun.partial(fun.partial(1), repr, on_path)
    
    local function pair_format (v, k) 
		return fun.apply(string.format, config.pair.style, seq.map(repr_with(depth + 1), {ipairs({k, v})}))
    end
    
    local was = on_path[tab]
    on_path[tab] = true
    
    local address = pack(
        ignore_if_not(
	        config.show_address, 
	        rawtostring, tab
	    )
    )
    local metatable = pack(
        ignore_if_not(
            not was and config.show_metatable, 
	        repr_with(depth + 2), debug.getmetatable(tab)
        )
    )
    local meta_info = pack(
        ignore_if_not(
            config.show_address or config.show_metatable, 
            array_format, address .. metatable, config.meta_info, depth + 2
        )
    )

    local map_entries = was and pack(config.circular_reference.substitution) 
	                         or seq.take(seq.map(pair_format, {next, tab}))
    
    local use_config = was and config.circular_reference or config.content
    local result = array_format(meta_info .. map_entries, use_config, depth + 1)

    if not was then 
        on_path[tab] = nil
    end
    
    return result
end

return {
    repr = repr, 
    NEAT = {
        table = {
            content = {
                sep = ',\n'
            }, 
            circular_reference = {
                sep = ' '
            }
        }
    },
    VERBOSE = {
        table = {
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
    }
}
