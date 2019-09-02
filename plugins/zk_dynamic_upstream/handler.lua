local require = require
local str_format = string.format
local tostring = tostring
local ngx  = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local ngx_DEBUG = ngx.DEBUG
local base_handler = require("plugins.base_handler")
local req_var_extractor = require("core.req.req_var_extractor")
local resp_utils = require("core.resp.resp_utils")
local plugin_config = require("plugins.zk_dynamic_upstream.config")
local zk_utils = require("plugins.zk_dynamic_upstream.zk_utils")
local json = require("core.utils.json")
local utils = require("core.utils.utils")
local PRIORITY = require("plugins.handler_priority")
local error_utils = require("core.utils.error_utils")
local error_type_biz = error_utils.types.ERROR_BIZ.name
local error_type_sys = error_utils.types.ERROR_SYSTEM.name

local log_config = require("core.utils.log_config")
local singletons = require("core.framework.singletons")
local balancer_helper = require("core.router.balancer_helper")
local ngx_balancer = require "ngx.balancer"
local get_last_failure = ngx_balancer.get_last_failure
local set_current_peer = ngx_balancer.set_current_peer
local set_timeouts     = ngx_balancer.set_timeouts
local set_more_tries   = ngx_balancer.set_more_tries



local api_route_handler = base_handler:extend()

local plugin_name = plugin_config.plugin_name

api_route_handler.PRIORITY = PRIORITY.api_router

local function now_micro_seconds()
    return ngx.now() * 1000
end

--
--refresh balancer address information from shared cache in balancer phase
--@param address will be refresh
--
local function refresh_balancer_address(addr)
    addr.targets = singletons.upstream_servers
end

function api_route_handler:new(app_context)
    api_route_handler.super.new(self, plugin_name)
    self.app_context = app_context
end

function api_route_handler:init_worker_timer()
    api_route_handler.super.init_worker_timer(self)
    --local http_client_config = self.app_context.config.http_client
    --zk_utils.get_upstream_nodes_via_http_exporter(http_client_config)
    local zookeeper_config=  self.app_context.config.zookeeper_conf
    zk_utils.get_upstream_nodes_via_tcp(zookeeper_config)
end

function api_route_handler:access()
    api_route_handler.super.access(self)
    local balancer_address = {}
    local upstream_servers = singletons.upstream_servers
    balancer_address.targets = upstream_servers
    balancer_address.wheel_size = #upstream_servers or 0
    balancer_address.retries_count = #upstream_servers or 0
    balancer_address.balance_algo = balancer_helper.LB_ALGO.ROUND_ROBIN
    balancer_address.connection_timeout =  10000
    balancer_address.send_timeout =   60000
    balancer_address.read_timeout =  60000
    balancer_address.has_tried_count = 0
    balancer_address.tries = {}
    local ok, err = balancer_helper.execute(balancer_address)
    if not ok then
        local msg = "failed to retry the dns/balancer resolver for upstream servers with: ".. tostring(err)
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

        error_utils.add_error_2_ctx(error_type_biz, plugin_config.small_error_types.biz.type_no_available_balancer)
        resp_utils.say_response_UPSTREAM_ERROR(tostring(err))
        return
    end
    local ip = balancer_address.ip
    local port = balancer_address.port
    if not ip or not port then
        local msg = "failed to retry the dns/balancer resolver for upstream servers with: ip or host id invalid.";
        ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

        error_utils.add_error_2_ctx(error_type_sys, plugin_config.small_error_types.sys.type_balancer_execute_error)
        resp_utils.say_response_UPSTREAM_ERROR(msg)
        return
    end
    ngx.ctx.balancer_address = balancer_address
end

--
--  upstream balancer execute, it can be executed more than one times
--  1. set current upstream node
--  2. set retries times
--  2. set timeouts to upstream node: connection_timeout, send_timeout, read_timeout
--
function api_route_handler : balancer()
    api_route_handler.super: balancer()
    ngx_log(ngx_DEBUG,"in api_router balancer  ============")
    local addr = ngx.ctx.balancer_address
    addr.has_tried_count = addr.has_tried_count + 1
    ngx_log(ngx_DEBUG,"addr.has_tried_count  ============" .. addr.has_tried_count)
    local las_status_code
    local tries = addr.tries
    local current_try = {}
    tries[addr.has_tried_count] = current_try
    current_try.balancer_start = now_micro_seconds()
    if addr.has_tried_count > 1 then
        -- only call balancer on retry, first one is done in `access` which runs
        -- in the ACCESS context and hence has less limitations than this BALANCER
        -- context where the retries are executed

        local previous_try = tries[addr.has_tried_count - 1]
        previous_try.state, previous_try.code = get_last_failure()
        las_status_code = previous_try.code

        refresh_balancer_address(addr)
        local ok, err =balancer_helper.execute(addr)
        if not ok then

            local msg = "failed to retry the dns/balancer resolver for ".. addr.upstream_service_id ..  "' with: " ..  tostring(err)
            ngx_log(ERR,str_format(log_config.biz_error_format,log_config.ERROR,msg))

            error_utils.add_error_2_ctx(error_type_sys, plugin_config.small_error_types.sys.type_balancer_execute_error)

            ngx.exit(502)
            return
        end
    else
        -- first try to execute balancing, so set the max number of retries
        local retries = addr.retries_count
        if retries > 0 then
            local method_name = req_var_extractor.extract_method()
            if not utils.is_non_idempotent(method_name) then
                set_more_tries(retries)
            end
        end
    end

    current_try.ip   = addr.ip
    current_try.port = addr.port
    local ip = addr.ip
    local port = addr.port
    ngx_log(ngx_DEBUG,"set_current_peer ip=", addr.ip, ", port=", port)
    local ok, err = set_current_peer(ip, port)
    if not ok then

        local msg = "failed to set the current peer (address: " ..  tostring(ip), " port: " .. tostring(port), "): " .. tostring(err);
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,msg))

        error_utils.add_error_2_ctx(error_type_sys, plugin_config.small_error_types.sys.type_balancer_execute_error)

        return ngx.exit(502);
    end

    ok, err = set_timeouts(addr.connection_timeout / 1000, addr.send_timeout / 1000, addr.read_timeout /1000)
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"could not set upstream timeouts: "..err))
    end
    -- record try-latency
    local try_latency = now_micro_seconds() - current_try.balancer_start
    current_try.balancer_latency = try_latency
    current_try.balancer_start = nil
end

return api_route_handler