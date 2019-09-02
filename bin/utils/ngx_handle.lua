local logger = require("bin.utils.logger")

local function create_dirs(necessary_dirs)
    if necessary_dirs then
        for _, dir in pairs(necessary_dirs) do
            os.execute("mkdir -p " .. dir .. " > /dev/null")
        end
    end
end

local function ngx_command(args)
    if not args then 
        error("error args to execute nginx command.") 
        os.exit(1)
    end

    local prefix, ngx_conf, ngx_signal = "", "", ""
    local orProxy_conf_info, prefix_info = "",""
    if args.orProxy_conf ~= nil then
        orProxy_conf_info = "ORPROXY_CONF=" .. args.orProxy_conf .. " "
    end
    if args.prefix then
        prefix = "-p " .. args.prefix
        prefix_info = "ORPROXY_PREFIX=" .. args.prefix
    end
    if args.ngx_conf then
        ngx_conf = "-c " .. args.ngx_conf
    end
    -- ngx master signal
    if args.ngx_signal then
        ngx_signal = "-s " .. args.ngx_signal
    end

    local cmd = string.format("nginx %s %s %s", prefix, ngx_conf, ngx_signal)
    local execute_info = string.format("Using: %s %s", orProxy_conf_info, prefix_info)
    logger:info(execute_info)
    return os.execute(cmd)
end


local _M = {}

function _M:new(args)
    local instance = {
        orProxy_conf = args.orProxy_conf,
        prefix = args.prefix,
        ngx_conf = args.ngx_conf,
        necessary_dirs = args.necessary_dirs
    }

    setmetatable(instance, { __index = self })
    return instance
end

-- start nginx
function _M:start()
    logger:info("Starting orProxy Server......")
    create_dirs(self.necessary_dirs)

    return ngx_command({
        orProxy_conf = self.orProxy_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = nil
    })
end

-- execute nginx stop signal
function _M:stop()
    logger:info("Stopping  Server......")
    return ngx_command({
        orProxy_conf = self.orProxy_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = "stop"
    })
end

-- execute nginx reload signal
function _M:reload()
    logger:info("Reloading  Server.......")
    create_dirs(self.necessary_dirs)
    return ngx_command({
        orProxy_conf = self.orProxy_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = "reload"
    })
end

return _M
