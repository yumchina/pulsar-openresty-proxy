local ngx_handle = require("bin.utils.ngx_handle")
local logger = require("bin.utils.logger")
local pl_path = require "pl.path"

local _M = {}


_M.help = [[
Usage: orProxy stop [OPTIONS]

Stop orProxy with configurations(prefix/orProxy_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) orProxy configuration file
 -h,--help (optional string) show help tips

Examples:
 orProxy stop  #use `/usr/local/orProxy` as workspace with `/usr/local/orProxy/conf/orProxy.conf` & `/usr/local/orProxy/conf/nginx.conf`
 orProxy stop --prefix=/opt/orProxy  #use the `prefix` as workspace with ${prefix}/conf/orProxy.conf & ${prefix}/conf/nginx.conf
 orProxy stop --conf=/opt/orProxy/conf/orProxy.conf --prefix=/opt/orProxy
 orProxy stop -h --help #just show help tips
]]

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        orProxy_conf = origin_args.conf,
        prefix = origin_args.prefix
    }
    for i, v in pairs(origin_args) do
        if i ~= "c" and i ~= "p" and i ~= "conf" and i ~= "prefix" then
            logger:error("Command stop option[name=%s] do not support.", i)
            return
        end
        if i == "c" and not args.orProxy_conf then
            args.orProxy_conf = v

        end
        if i == "p" and not args.prefix then
            args.prefix = v
        end
    end

    -- use default args if not exist /usr/local/orProxy
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
    local pids_path = args.prefix .. "/pids"
    local pid_path = pids_path .. "/nginx.pid"
    if not pl_path.exists(pid_path ) then
        logger:info("\t OrProxy had stopped before, do not need execute stop command again.")
        return
    end
    local err
    xpcall(function()
        local handler = ngx_handle:new(args)
        local result = handler:stop()
        if result  then
            logger:success("OrProxy server stopped.")
        else
            os.exit(1)
        end
    end, function(e)
        logger:error("Could not stop OrProxy, error: %s", e)
        err = e
    end)

    if err then
        error(err)
        os.exit(1)
    end
end


return _M
