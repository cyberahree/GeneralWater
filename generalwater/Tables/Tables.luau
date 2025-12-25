--!strict
local Module = {}

function Module.Reverse(t: { any })
    -- directly write to the table to avoid extra allocations
    local n = #t

    for i = 1, math.floor(n / 2) do
        t[i], t[n - i + 1] = t[n - i + 1], t[i]
    end

    return t
end

function Module.ShallowCopy<T>(t: { any: any }): { any: any }
    local result: { any: any } = {}

    for k, v in pairs(t) do
        result[k] = v
    end

    return result
end

function Module.DeepCopy<T>(t: { any: any }): { any: any }
    local result: { any: any } = {}

    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = Module.DeepCopy(v)
        else
            result[k] = v
        end
    end

    return result
end

return Module
