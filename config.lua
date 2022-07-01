--
-- Forms a subconfig with all the keys from @keys,
-- and values from @table first, or defaults from @keys
--
local function subconfig(tabl, conf)
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

return {subconfig = subconfig}
