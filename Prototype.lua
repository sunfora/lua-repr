local prototype = {}

--
-- Checks whether the table has prototype in its prototype-chain
--
function prototype.instanceof (table, prototype)
    assert(type(table) == 'table', 'instanceof of type ' .. type(table) .. ' not supported')
    while table do
        if table == prototype then 
            return true
        end
        table = getmetatable(table)
	table = table and table.__index
    end
    return false
end

return prototype
