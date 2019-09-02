-- Author AlbertXiao

local zk = require "resty.zookeeper-client.zk"
local tablen = table.getn
local print = print
local ngx = ngx
local ngx_log = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local setmetatable = setmetatable
local now = ngx.now
local sleep = ngx.sleep

local _M = { __version = "0.01" }

local mt = { __index = _M }

function _M.new(self, config)
    if not self.inited then
        self.child_getting_state = {}
        self.data_getting_state = {}
        self.child_cache = {}
        self.data_cache = {}
        self.inited = true
        --print('initt.....')
    end
    local timeout = config.timeout or 1000
    local expire = config.expire or 1
    return setmetatable({serv_list=config.servers, timeout=timeout, expire=expire}, mt)
end

function _M._get_host(self)
    local serv_list = self.serv_list
    local random = math.random(tablen(serv_list))
    return serv_list[random]
end

function _M._connect(self)
    local conn = zk:new()
    conn:set_timeout(self.timeout)
    local host = self:_get_host()
    ngx_log(DEBUG, "trying to connect to zookeeper host: " .. host)
    local ok, err = conn:connect(host)
    if not ok then
        print("connect " .. host .. " error:" ..err)
        ngx_log(ERR,"connect " .. host .. " error:" ..err)
    else
        self.conn = conn
        return conn
    end
    return nil
end

--
-- 注意：将use_cache设置为false，不要使用use_cache
-- cache貌似有内存泄漏child_getting_state，data_getting_state，child_cache，data_cache未有过期设置
--
function _M._common_get(self, path, get_type, use_cache)
    local use_cache = use_cache or true
    local expire = self.expire
    local cache = nil
    local getting_state = nil
    local res
    local err

    if get_type == 'child' then
        cache = self.child_cache
        getting_state = self.child_getting_state
    elseif get_type == 'data' then
        cache = self.data_cache
        getting_state = self.data_getting_state
    end

    local getting = getting_state[path]
    if use_cache then
        local c = cache[path]
        if c then
            local value = c['v']
            if now() - c['expire'] < expire then
                --print('hit cache')
                return value
            else
                if getting then
                    --print('already getting, use stale cache')
                    return value
                else
                    --print('cache expired, freshing')
                    getting_state[path] = true
                    if get_type == 'child' then
                        res, err = self:_get_children(path)
                    elseif get_type == 'data' then
                        res, err = self:_get_data(path)
                    end
                    getting_state[path] = false
                    if res then
                        return res
                    else
                        return value
                    end
                end
            end
        else
            if getting then
                --print('already getting, sleep 1 seconds')
                sleep(1)
                c = cache[path]
                return c['v']
            else
                --print('first get')
                getting_state[path] = true
                if get_type == 'child' then
                    res, err = self:_get_children(path)
                elseif get_type == 'data' then
                    res, err = self:_get_data(path)
                end
                getting_state[path] = false
                return res
            end
        end
    else
        if get_type == 'child' then
            return self:_get_children(path)
        elseif get_type == 'data' then
            return self:_get_data(path)
        end
    end
end

function _M.get_children(self, path, use_cache)
    return self:_common_get(path, 'child', use_cache)
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
    local c = {v=res, expire=now()}
    self.child_cache[path] = c
    return res
end

function _M.get_data(self, path, use_cache)
    return self:_common_get(path, 'data', use_cache)
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
    local c = {v=res, expire=now()}
    self.data_cache[path] = c
    return res
end

return _M

