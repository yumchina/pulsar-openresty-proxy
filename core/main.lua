--[[
 ProxyOR Gateway APPLICATION 主程序入口
 created by Jacobs Lei @2018-03-26
--]]

local pcall = pcall
local require = require
local pairs  = pairs
local singletons = require("core.framework.singletons")
local config_loader = require ("core.utils.config_loader")
local server_info = require("core.server_info")
local utils = require("core.utils.utils")
local table_insert = table.insert
local table_sort = table.sort
local upstream_error_handlers = require("core.upstream_error_handlers")
local log_config = require("core.utils.log_config")
local ngx = ngx
local ngx_log = ngx.log
local ERR = ngx.ERR
local ipairs = ipairs
local timer_at = ngx.timer.at
local str_format = string.format
local resty_lock = require("resty.lock")
local shard_name = require("core.constants.shard_name")
local custom_headers = require("core.utils.custom_headers")
local xpcall_helper = require("core.utils.xpcall_helper")
require("core.framework.globalpatches")()


-- Response Header definition
local HEADERS = {
    -- proxy process latency time
    PROXY_LATENCY = custom_headers.PROXY_LATENCY,
    -- upstream server process latency
    UPSTREAM_LATENCY = custom_headers.UPSTREAM_LATENCY,
    -- upstream balance lantency time
    BALANCER_LATENCY = custom_headers.BALANCER_LATENCY,
    SERVER = custom_headers.SERVER,
    VIA = custom_headers.VIA,
    SERVER_PROFILE = custom_headers.SERVER_PROFILE
}

-- Application main 
local OrProxy = {}

---Get current time in ms
local function now()
    return ngx.now() * 1000
end


---
--- initializing plugins' handler information
---@param app_context  table
---
local function load_conf_plugin_handlers(app_context)
    ngx.log(ngx.DEBUG, "Loading orProxy.conf's plugins node.")
    local sorted_plugins = {}
    local plugins = app_context.config.plugins

    for _, plugin_name in ipairs(plugins) do
        local loaded, plugin_handler = utils.load_module_if_exists("plugins." .. plugin_name .. ".handler")
        if not loaded then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"The following plugin is not installed or has no handler: " .. plugin_name))
        else
            ngx.log(ngx.DEBUG, "Loading plugin: " .. plugin_name)
            table_insert(sorted_plugins, {
                name = plugin_name,  --plugin name
                handler = plugin_handler(app_context)  --plugin handler module
            })
        end
    end

    table_sort(sorted_plugins, function(a, b)
        local priority_a = a.handler.PRIORITY or 0
        local priority_b = b.handler.PRIORITY or 0
        return priority_a > priority_b
    end)

    return sorted_plugins
end


local function plugin_init_worker_timer(premature, config)
    if premature then
        return
    end
    local worker_id = ngx.worker.id()
    local lock = resty_lock:new(shard_name.lock,{
        exptime = 20,  -- timeout after which lock is released anyway
        timeout = 10,   -- max wait time to acquire lock
    })
    local lock_key = "plugin_init_worker_timer_lock_"..worker_id
    local elapsed, err = lock:lock(lock_key)
    if elapsed and not err then
        ngx.log(ngx.DEBUG, "OrProxy plugin configuration data's initialization execute at workers[id=", worker_id,"]")
        for _, plugin in ipairs(singletons.loaded_plugins) do
            xpcall_helper.execute(function()
                plugin.handler:init_worker_timer()
            end)
        end
        local ok, err = lock:unlock()
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to  release the lock(plugin): "..err))
        end
    else
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"failed to acquire the lock(plugin): "..err))
    end

    local timer_interval = config.load_conf_interval or 10
    local ok, err = timer_at(timer_interval, plugin_init_worker_timer, config);
    if not ok then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"OrProxy workers failed to create loading configuration timer:".. err))
        return
    end
end


local function init_worker(premature, config)
    if premature then
        return
    end
    plugin_init_worker_timer(premature, config)
end


--- ORPROXY core applicaition  initializing is beginning ---------
--[[application initialize configuration
	such as global configuration, upstream nodes information
--]]
function OrProxy.init(global_conf_path)
    ngx.log(ngx.INFO, "OrProxy Application is starting loading configuration.")
    local app_context ={}
    local status, err = pcall(function()
    	-- 加载所有全局配置
        app_context.config = config_loader.load(global_conf_path)
        if app_context.config.application_conf.service_type == "gateway_service" then
            singletons.loaded_plugins = load_conf_plugin_handlers(app_context)
        end

        ngx.update_time()
        app_context.config.orProxy_start_at = ngx.localtime()
    end)

    if not status or err then
        ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"OrProxy Application Startup error: "..err))
        os.exit(1)
    end
    OrProxy.data = {
    	config = app_context.config,
        start_time = app_context.config.orProxy_start_at,
        profile = app_context.config.profile
	}
	return app_context.config
end


--[[
--initialize nginx worker's configuration
--setting the schedule program
--]]
function OrProxy.initWorker()
	-- 仅在 init_worker 阶段调用，初始化随机因子，仅允许调用一次
    math.randomseed()

    -- 初始化定时器，清理计数器
    if OrProxy.data  then
        local timer_delay = OrProxy.data.config.load_conf_delay or 0
        local ok, err = timer_at(timer_delay, init_worker,OrProxy.data.config)
        if not ok then
            ngx_log(ERR,str_format(log_config.sys_error_format,log_config.ERROR,"OrProxy workers failed to create loading configuration timer: "..err))
            return os.exit(1)
        end
    end
end


--[[
 访问控制执行阶段执行逻辑： 如路由控制，防火墙控制， 全局限流控制, 基于特征限流控制等
 具体执行逻辑由插件执行
--]]
function OrProxy.access()
	ngx.ctx.ORPROXY_ACCESS_START = now()

    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:access()
    end
    local now_time = now()
    ngx.ctx.ORPROXY_ACCESS_TIME = now_time - ngx.ctx.ORPROXY_ACCESS_START
    ngx.ctx.ORPROXY_ACCESS_ENDED_AT = now_time
    ngx.ctx.ORPROXY_ACCESS_LATENCY = now_time - ngx.req.start_time() * 1000
    ngx.ctx.ACCESSED = true
end

--[[
 响应头过滤阶段执行逻辑
 具体执行逻辑由插件执行
--]]
function OrProxy.header_filter()
	if ngx.ctx.ACCESSED  then
        local now_time = now()
         -- time spent waiting for a response from upstream
        if ngx.ctx.BALANCERED then
            ngx.ctx.ORPROXY_WAITING_TIME = now_time - ngx.ctx.ORPROXY_BALANCER_ENDED_AT
        else
            ngx.ctx.ORPROXY_WAITING_TIME = now_time - ngx.ctx.ORPROXY_ACCESS_ENDED_AT
        end
        ngx.ctx.ORPROXY_HEADER_FILTER_STARTED_AT = now_time

    end

    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:header_filter()
    end

    if ngx.ctx.ACCESSED then
        ngx.header[HEADERS.UPSTREAM_LATENCY] = ngx.ctx.ORPROXY_WAITING_TIME
        if ngx.ctx.BALANCERED then
            ngx.header[HEADERS.PROXY_LATENCY] = ngx.ctx.ORPROXY_ACCESS_LATENCY + ngx.ctx.ORPROXY_BALANCER_LATENCY
            ngx.header[HEADERS.BALANCER_LATENCY] = ngx.ctx.ORPROXY_BALANCER_LATENCY
        else
            ngx.header[HEADERS.PROXY_LATENCY] = ngx.ctx.ORPROXY_ACCESS_LATENCY
        end

    end
    ngx.header[HEADERS.SERVER] = server_info.full_name
    ngx.header[HEADERS.VIA] = server_info.full_name
    ngx.header[HEADERS.SERVER_PROFILE] = OrProxy.data.start_time .. "/" .. OrProxy.data.profile

    -- 其它头信息
    local add_headers = custom_headers.get_add_headers()
    if add_headers then
        for key, value in pairs(add_headers) do
            ngx.header[key] = value
        end
    end

end

--[[
--响应体过滤控制执行逻辑
  具体执行逻辑由插件执行
]]
function OrProxy.body_filter()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:body_filter()
    end

    if ngx.ctx.ACCESSED then
        ngx.ctx.ORPROXY_RECEIVE_TIME = now() - ngx.ctx.ORPROXY_HEADER_FILTER_STARTED_AT
    end
end
--[[
--日志阶段执行逻辑
--具体执行逻辑由插件执行
--]]
function OrProxy.log()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:log()
    end
end

--[[
-- upstream interval error的处理逻辑
--]]
function OrProxy.error_handle()
    return upstream_error_handlers(ngx,OrProxy.data.cache_client)
end

--[[
-- upstream balancer phase execute logic:
 ]]
function OrProxy.balancer()
    ngx.ctx.ORPROXY_BALANCER_START_AT = now()
    for _, plugin in ipairs(singletons.loaded_plugins) do
        plugin.handler:balancer()
    end
    local now_time = now()
    ngx.ctx.ORPROXY_BALANCER_LATENCY = now_time - ngx.ctx.ORPROXY_BALANCER_START_AT
    ngx.ctx.ORPROXY_BALANCER_ENDED_AT = now_time
    ngx.ctx.BALANCERED = true
end

----- ORPROXY core application initializing finished -----------

return OrProxy