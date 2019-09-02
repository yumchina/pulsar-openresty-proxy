local ngx_handle = require("bin.utils.ngx_handle")
local logger = require("bin.utils.logger")
local init_conf = require("bin.initconf.init_conf")
local pl_path = require "pl.path"
local server_info = require("core.server_info")
local server_name = server_info.name

local function new_handler(args)
    args.necessary_dirs ={ -- runtime nginx conf/pid/logs dir
        tmp = args.prefix .. '/tmp',
        logs = args.prefix .. '/logs',
        pids = args.prefix .. '/pids'
    }

    return ngx_handle:new(args)
end


local _M = {}


_M.help = string.format([[
Usage: %s start [OPTIONS]

Start %s with configurations(prefix/orProxy_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) orProxy(orProxy.json) configuration file
 -h,--help (optional string) show help tips

Examples:
 %s start  #use `/usr/local/orProxy` as workspace with /etc/orProxy/orProxy.json`
 %s start --prefix=/opt/orProxy  #use the `prefix` as workspace with  ${prefix}/conf/nginx.conf
 %s start --conf=/opt/orProxy/conf/orProxy.json  as orProxy's configuration
 %s start -h  #just show help tips
]], server_name,server_name,server_name,server_name,server_name,server_name)

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        orProxy_conf = origin_args.conf,
        prefix = origin_args.prefix
    }
    for i, v in pairs(origin_args) do
        if i ~= "c" and i ~= "p" and i ~= "conf" and i ~= "prefix" then
            logger:error("Command Start option[name=%s] do not support.", i)
            return
        end
        if i == "c" and not args.orProxy_conf then
            args.orProxy_conf = v

        end
        if i == "p" and not args.prefix then
            args.prefix = v
        end
    end

    -- use default args if not exist
    if not args.prefix then
        args.prefix = "/usr/local/orProxy"
    end
    if not args.orProxy_conf then
        args.orProxy_conf = "/etc/orProxy/orProxy.json"
        if not pl_path.exists(args.orProxy_conf) then
            args.orProxy_conf = args.prefix .. "/conf/orProxy.json"
        end
    end
    args.ngx_conf = args.prefix .. "/conf/nginx.conf"

    if args then
        logger:info("args:")
        for i, v in pairs(args) do
            logger:info("\t %s:%s", i, v)
        end
    end

    local err
    xpcall(function()
        local ok, err= init_conf(args)
        if not ok or err then
            logger:error("OrProxy server started failed.err:%s", err)
            os.exit(1)
        end
        local handler = new_handler(args)
        local result = handler:start()
        if result then
            logger:success("OrProxy server started.")
        else
            os.exit(1)
        end
    end, function(e)
        logger:error("Could not start OrProxy server, stopping it")
        pcall(pcall(function()
            local handler = new_handler(args)
            handler:stop()
        end))
        err = e
        logger:warn("Stopped orProxy server")
    end)

    if err then
        error(err)
        os.exit(1)
    end
end


return _M
