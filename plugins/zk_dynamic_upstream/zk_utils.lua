---
---Zookeeper exporter operating client, operating zookeeper by Http protocol
---@author Jacobs Lei
---@since 2019-06-16
---

local require = require
local str_format = string.format
local ipairs = ipairs
local table_insert = table.insert
local ngx = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local http_client = require("core.utils.http_client")
local log_config = require("core.utils.log_config")
local json = require("core.utils.json")
local zk = require("core.zk_client.zk_cluster")
local string_util = require("core.utils.stringy")
local singletons = require("core.framework.singletons")
local plugin_config = require("plugins.zk_dynamic_upstream.config")




local function build_get_upstream_nodes_req_param(uri)

    local req = {}
    local headers = {}
    headers["content-type"] = "application/json"
    req["uri"] = uri
    req["headers"] = headers
    req["method"] = "POST"
    req["query"] = query
    return req
end


local _M = {}

---
---Get dynamic upstream server nodes information from zookeeper exporter service
---@param http_client_config table
---
function _M.get_upstream_nodes_via_http_exporter(http_client_config)
    local http_client = http_client(http_client_config)
    local zk_exporter_host = http_client_config.request_addresses["zookeeper_exporter" ]
    local uri = zk_exporter_host .. "/zk/children?parent=loadbalance/brokers"
    local req = build_get_upstream_nodes_req_param(uri)
    local resp,err = http_client:send(req)
    if not resp then
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,"request zookeeper exporter error:" .. err))
    end
    if resp.body then
        local full_host_array = json.decode(resp.body)
        local targets = {}
        local start_index = 1
        for _, full_host in ipairs(full_host_array) do
            local ip_port = string_util.split(full_host,":")
            local target = {}
            target.ip = ip_port[1]
            if ip_port[2] then
                target.port = ip_port[2]
            end
            target.healthy = true
            target.weight = 1
            target.start_idx = start_index
            target.end_idx = target.start_idx + target.weight -1
            table_insert(targets,target)
            start_index = target.end_idx + 1
        end
        singletons.upstream_servers = targets;
        ngx_log(DEBUG, json.encode(singletons.upstream_servers))
    else
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,
                "zookeeper exporter server error, it can not get upstream nodes information." ))
    end

    if http_client then
        http_client:close()
    end
end


function _M.get_upstream_nodes_via_tcp(zookeeper_config)
    local zc = zk:new(zookeeper_config)
    local children, err = zc:get_children(plugin_config.upstream_zk_register_path)
    if not children  then
        local error_msg =  "proxy can not discovery upstream nodes from zookeeper cluster, because:" .. err
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR, error_msg))
    else
        local targets = {}
        local start_index = 1
        for _, full_host in ipairs(children) do
            local ip_port = string_util.split(full_host,":")
            local target = {}
            target.ip = ip_port[1]
            if ip_port[2] then
                target.port = ip_port[2]
            end
            target.healthy = true
            target.weight = 1
            target.start_idx = start_index
            target.end_idx = target.start_idx + target.weight -1
            table_insert(targets,target)
            start_index = target.end_idx + 1
        end
        singletons.upstream_servers = targets;
        ngx_log(DEBUG, json.encode(singletons.upstream_servers))

    end
end


return _M


