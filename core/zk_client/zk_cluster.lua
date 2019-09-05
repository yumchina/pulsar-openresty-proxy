local zk = require "core.zk_client.zk"
local str_format = string.format
local tablen = table.getn
local ngx = ngx
local ngx_log = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local setmetatable = setmetatable
local singletons = require("core.framework.singletons")
local log_config = require("core.utils.log_config")


local _M = { __version = "0.01" }

local mt = { __index = _M }

function _M.new(self, config)
    if not self.inited then
        self.child_getting_state = {}
        self.data_getting_state = {}
        self.child_cache = {}
        self.data_cache = {}
        self.host_try_time = 2
        self.inited = true
    end
    local timeout = config.timeout or 1000
    return setmetatable({serv_list=config.servers, timeout=timeout}, mt)
end

function _M._get_host(self)
    local serv_list = self.serv_list
    local size = tablen(serv_list)
    if singletons.upstream_round_robin_index > size then
        singletons.upstream_round_robin_index = 1
    end
    local selected_host =  serv_list[singletons.upstream_round_robin_index]
    singletons.upstream_round_robin_index = singletons.upstream_round_robin_index + 1
    return selected_host

end

function _M._connect(self)
    local conn = zk:new()
    conn:set_timeout(self.timeout)
    local max_connect_times = tablen(self.serv_list)*self.host_try_time
    for  _ = 1, max_connect_times do
        local host = self:_get_host()
        ngx_log(DEBUG, "trying to connect to zookeeper host: " .. host)
        local ok, err = conn:connect(host)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format, log_config.ERROR, "connect " .. host .. " error:" ..err))
        else
            self.conn = conn
            return conn
        end
    end
    return nil
end

function _M._common_get(self, path, get_type)

    if get_type == 'child' then
        return self:_get_children(path)
    elseif get_type == 'data' then
        return self:_get_data(path)
    end
end

function _M.get_children(self, path)
    return self:_common_get(path, 'child')
end

function _M._get_children(self, path)
    local conn = self.conn
    if not conn then
        conn = self:_connect()
        if not conn then
            return nil, "connect error"
        end
    end

    local res, err = conn:get_children(path)
    if not res then
        conn:close()
        self.conn = nil
        return nil, err
    end
    return res
end

function _M.get_data(self, path)
    return self:_common_get(path, 'data')
end

function _M._get_data(self, path)
    local conn = self.conn
    if not conn then
        conn = self:_connect()
        if not conn then
            return nil, "connect error"
        end
    end
    local res, err = conn:get_data(path)
    if not res then
        conn:close()
        self.conn = nil
        return nil, err
    end
    return res
end

return _M

