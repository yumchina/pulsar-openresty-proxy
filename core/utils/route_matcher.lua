---
--- route_matcher
--- Created by yusai.
--- DateTime: 2018/11/8 下午1:56
---
local str_sub = string.sub
local str_find = string.find
local str_len = string.len
local local_cache = require("core.cache.local.global_cache_util")
local local_cache_prefix = require("core.cache.local.global_cache_prefix")
local default_group_context = "-default-"
local _M={}

-- 参数整形
-- 以非"/"开头,整形以"/"结尾
local function param_shaping(param)
    local len =str_len(param);
    if len >1 then
        local prefix = str_sub(param,1,1);
        local postfix = str_sub(param,len);
        if prefix == "/" then
            param = str_sub(param,2)
        end
        if postfix ~= "/" then
            param = param .."/"
        end
    end

    return param;
end

local function _match(uri,group_contexts)
    if group_contexts and #group_contexts > 0 then
        for _, group_context in ipairs(group_contexts) do
            local indx = str_find(param_shaping(uri), param_shaping(group_context),1,true)
            if indx and indx == 1 then
                return group_context;
            elseif group_context == default_group_context then
                return default_group_context
            end
        end
    end
    return nil
end

function _M.match(uri,host)
    local group_contexts = local_cache.get_json(local_cache_prefix.host_api_group_context .. host);
    return _match(uri,group_contexts);
end


return _M;