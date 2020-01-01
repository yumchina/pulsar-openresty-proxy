---
--- Safely call method's helper
--- Copyright (c)2020  YumChina & Jacobs Lei
--- Author: Jacobs Lei
--- Date: 2018/6/7
--- Time: 下午5:40

local xpcall = xpcall
local debug = debug
local ngx_log = ngx.log
local ngx_err = ngx.ERR

local _M = {}

function _M.execute(func,final_func)
    local ok, e
    ok = xpcall(
        func, function()
        e = debug.traceback()
        if  final_func then
            final_func()
        end
    end)

    if not ok or e then
        ngx_log(ngx_err, "execute error traceback : ", e)
    end
end


return _M