local require = require
local cjson = require("cjson.safe")

local _M = {}

function _M.encode(data, empty_table_as_object)
    if not data then return nil end

    if cjson.encode_empty_table_as_object then
        -- default,empty table encode as array
        cjson.encode_empty_table_as_object(empty_table_as_object or false)
    end

    if require("ffi").os ~= "Windows" then
        -- spare array index as string
        cjson.encode_sparse_array(true)
    end

    return cjson.encode(data)
end


function _M.decode(data)
    if not data then return nil end

    return cjson.decode(data)
end


return _M
