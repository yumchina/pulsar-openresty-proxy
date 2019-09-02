local ngx_handle = require("bin.utils.ngx_handle")
local init_conf = require("bin.initconf.init_conf")
local pl_path = require "pl.path"
local start_cmd = require("bin.cmds.start")
local logger = require("bin.utils.logger")


local _M = {}


_M.help = [[
Usage: orProxy reload [OPTIONS]

Reload orProxy with configurations(prefix/orProxy_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) orProxy configuration file
 -h,--help (optional string) show help tips

Examples:
 orProxy reload  #use `/usr/local/orProxy` as workspace with `/usr/local/orProxy/conf/orProxy.json`
 orProxy reload --prefix=/opt/orProxy  #use the `prefix` as workspace with ${prefix}/conf/orProxy.json & ${prefix}/conf/nginx.conf
 orProxy reload --conf=/opt/orProxy/conf/orProxy.json --prefix=/opt/orProxy
 orProxy reload -h  #just show help tips
]]

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        orProxy_conf = origin_args.conf,
        prefix = origin_args.prefix
    }
    for i, v in pairs(origin_args) do
        if i ~= "c" and i ~= "p" and i ~= "conf" and i ~= "prefix" then
            logger:error("Command reload option[name=%s] do not support.", i)
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
    -- if not args.prefix then args.prefix = command_util.pwd() end
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
    local pids_path = args.prefix .. "/pids"
    local pid_path = pids_path .. "/nginx.pid"
    if not pl_path.exists(pid_path ) then
        xpcall(function ()
            logger:warn("OrProxy is not running, changing to execute start command.")
            start_cmd.execute(origin_args)
        end ,function(e)
            logger:error("Could not start OrProxy, error: %s", e)
            err = e
        end)
    else
        xpcall(function()
            local ok, err= init_conf(args)
            if not ok or err then
                logger:error("OrProxy started failed.err:%s", err)
                os.exit(1)
            end
            local handler = ngx_handle:new(args)
            local result = handler:reload()
            if result  then
                logger:success("OrProxy reloaded.")
            else
                os.exit(1)
            end
        end, function(e)
            logger:error("Could not reload OrProxy, error: %s", e)
            err = e
        end)
    end

    if err then
        error(err)
        os.exit(1)
    end
end


return _M
