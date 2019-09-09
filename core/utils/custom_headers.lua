---
--- 自定义HTTP response 头信息
--- Created by Jacobs  Lei.
---

local _M={}

-- proxy process latency time
_M.PROXY_LATENCY = "X-Proxy-Latency"

-- upstream server process latency
_M.UPSTREAM_LATENCY = "X-Upstream-Latency"

-- upstream balance lantency time
_M.BALANCER_LATENCY = "X-Balancer-Latency"

_M.SERVER = "Server"

_M.VIA = "Via"

_M.SERVER_PROFILE = "X-Profile"

_M.PLUGIN_INTERCEPT = "X-Intercept"

function _M.add_header_to_ctx(key,value)
    local add_headers = ngx.ctx.add_headers
    if not add_headers then
        add_headers = {}
   end
    add_headers[key] = value
    ngx.ctx.add_headers = add_headers
end

function _M.get_add_headers()
    return ngx.ctx.add_headers
end

return _M;