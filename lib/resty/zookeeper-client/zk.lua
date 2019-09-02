-- Author AlbertXiao


local struct = require "resty.zookeeper-client.struct"

local tcp = ngx.socket.tcp
local pack = struct.pack
local unpack = struct.unpack
local strlen = string.len
local strsub = string.sub
local strbyte = string.byte
local bit = require "bit"
local bor = bit.bor
local exiting = ngx.worker.exiting
local sleep = ngx.sleep
local now = ngx.now
--constants

--error info
local ZNODEEXISTS = -110

--xids
local WATCHER_EVENT_XID = -1 
local PING_XID = -2
local AUTH_XID = -4
local SET_WATCHES_XID = -8
local CLOSE_XID = -9
-- ops
local ZOO_NOTIFY_OP = 0
local ZOO_CREATE_OP = 1
local ZOO_DELETE_OP = 2
local ZOO_EXISTS_OP = 3
local ZOO_GETDATA_OP = 4
local ZOO_SETDATA_OP = 5
local ZOO_GETACL_OP = 6
local ZOO_SETACL_OP = 7
local ZOO_GETCHILDREN_OP = 8
local ZOO_SYNC_OP = 9
local ZOO_PING_OP = 11
local ZOO_GETCHILDREN2_OP = 12
local ZOO_CHECK_OP = 13
local ZOO_MULTI_OP = 14
local ZOO_CLOSE_OP = -11
local ZOO_SETAUTH_OP = 100
local ZOO_SETWATCHES_OP = 101
--
local ZOO_EPHEMERAL = 1
local ZOO_SEQUENCE = 2

--
local ZNONODE = -101

local _M = {
    _VERSION = '0.01',
    EPHEMERAL = ZOO_EPHEMERAL,
    SEQUENCE = ZOO_SEQUENCE,
}

local mt = { __index = _M }

function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ sock = sock }, mt)
end

function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end

function _M.connect(self, host)
    local sock = self.sock
    local req = pack(">iililic16", 44, 0, 0, 0, 0, 0, "")
    if not sock then
        return nil, "not initialized"
    end

    local ok, err = sock:connect(host)
    if not ok then
        return nil, err
    end
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            if res then
                local v, t, sid, pl,p = unpack(">iilis", res)
                self.sn = 0
                self.session_timeout = t
                return true
            else
                return nil, err
            end
        end
    end
    return nil, "recv head error"
end

local function unpack_strings(str)
    local size = strlen(str)
    local pos = 0
    local str_set = {}
    local index = 1
    while size > pos do
        local len = unpack(">i", strsub(str, 1+pos, 4+pos))        
        local s = unpack(">c" .. len, strsub(str, 5+pos, 5+pos+len-1))
        str_set[index] = s
        index = index + 1
        pos = pos + len + 4
    end
    return str_set
end

function _M.get_children(self, path)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local sn = self.sn + 1
    local pathlen = strlen(path)
    local req = pack(">iiiic" .. pathlen .. "b", 12+pathlen+1, sn, ZOO_GETCHILDREN_OP, pathlen, path, strbyte(0))
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, "send error"
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            if strlen(res) > 16 then
                local sn, zxid, err, count = unpack(">ilii", res)
                self.sn = sn+1
                return unpack_strings(strsub(res, 21)) 
            else
                return nil, "recv error"
            end
        end
    end
    return nil, "recv head error"
end

function _M.get_data(self, path)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local sn = self.sn + 1
    local pathlen = strlen(path)
    local req = pack(">iiiic" .. pathlen .. "b", 12+pathlen+1, sn, ZOO_GETDATA_OP, pathlen, path, strbyte(0))
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            if strlen(res) > 16 then
                local sn, zxid, err, len = unpack(">ilii", res)
                self.sn = sn+1
                return strsub(res, 21, 21+len-1)
            else
                return nil, "recv error"
            end
        end
    end
    return nil, "recv head error"
end

function _M.create(self, path, data, opt)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local sn = self.sn + 1
    local pathlen = strlen(path)
    if not data or strlen(data) == 0 then
        data = " "
    end
    local datalen = strlen(data)
    
    local acl_scheme = "world"
    local acl_id = "anyone"
    local scheme_len = strlen(acl_scheme)
    local id_len = strlen(acl_id)
    local flag = 0
    if opt and opt[ZOO_EPHEMERAL] then
        flag = bor(flag, ZOO_EPHEMERAL)
    end
    if opt and opt[ZOO_SEQUENCE] then
        flag = bor(flag, ZOO_SEQUENCE)
    end
    local req = pack(">iiic" .. pathlen .. "ic" .. datalen .. "iiic" .. scheme_len .. "ic" .. id_len .. "i",
                    sn, ZOO_CREATE_OP, pathlen, path, datalen, data,
                    1, 0x1f, scheme_len, acl_scheme, id_len, acl_id, flag)
    req = pack(">ic" .. strlen(req), strlen(req), req)
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            if strlen(res) >= 16 then
                local sn, zxid, err = unpack(">ili", res)
                self.sn = sn+1
                if err == 0 then
                    len = unpack(">i", strsub(res, 17, 17+3))
                    return true, strsub(res, 21, 21+len-1)
                else
                    if err == ZNODEEXISTS then
                        err = "node exists"
                    end
                    return false, err
                end
            else
                return nil, "recv error"
            end
        end
    end
    return nil, "recv head error"
end

function _M.ping(self)
    local sock = self.sock
    local req = pack(">iII", 8, PING_XID, ZOO_PING_OP)
    if not sock then
        return nil, "not initialized"
    end
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            local xid = unpack(">i", strsub(res, 1, 1+3))
            if xid == PING_XID then
                return true
            else
                err = "unknow reponse"
            end
        end
    end
    return nil, err
end

function _M.exist(self, path)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local sn = self.sn + 1
    local pathlen = strlen(path)
    local req = pack(">iiiic" .. pathlen .. "b", 12+pathlen+1, sn, ZOO_EXISTS_OP, pathlen, path, strbyte(0))
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            if strlen(res) >= 16 then
                local sn, zxid, err = unpack(">ili", res)
                self.sn = sn+1
                if err == ZNONODE then
                    return false, "not exist"
                elseif err == 0 then
                    return true
                end
            else
                return nil, "recv error"
            end
        end
    end
    return nil, "recv head error"
end

function _M.get_pinginterval(self)
    --change to seconds
    return (self.session_timeout/3)/1000
end

function _M.loop_keepalive(self)
    local sleep_period = 0.1
    local last_send_time = 0
    while true do
        if exiting() then
            self:closesession()
            self:close()
            return true
        end
        if now() - last_send_time > self:get_pinginterval() then
            local ok, err = self:ping()
            if not ok then
                return nil, err
            end
            last_send_time = now()
        end
        sleep(sleep_period)
    end
end

function _M.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:close()
end

function _M.closesession(self)
    local sock = self.sock
    local req = pack(">iII", 8, CLOSE_XID, ZOO_CLOSE_OP)
    if not sock then
        return nil, "not initialized"
    end
    local bytes, err = sock:send(req)
    if not bytes then
        print(err)
        return nil, err
    end
    local res, err = sock:receive(4)
    if res then
        local len = unpack(">i", res)
        if len then
            res, err = sock:receive(len)
            local xid = unpack(">i", strsub(res, 1, 1+3))
            if xid == CLOSE_XID then
                print("recv close response")
            else
                print("recv unknow response")
            end
        end
    else
        return nil, err
    end
    return bytes
end
return _M

