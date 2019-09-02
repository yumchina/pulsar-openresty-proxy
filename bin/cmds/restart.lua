local start_cmd = require("bin.cmds.start")
local stop_cmd = require("bin.cmds.stop")
local logger = require("bin.utils.logger")


local _M = {}


_M.help = [[
Usage:  restart [OPTIONS]

Restart  with configurations(prefix/conf/orProxy.json).

Options:
 -p,--prefix  (optional string) override prefix directory
 -c,--conf (optional string) orProxy configuration file
 -h,--help (optional string) show help tips

Examples:
 orProxy restart
 orProxy restart --prefix=/opt/orProxy  #use the `prefix` as workspace with ${prefix}/conf/orProxy.conf & ${prefix}/conf/nginx.conf
 orProxy restart --conf=/opt/orProxy/conf/orProxy.json --prefix=/opt/orProxy
 orProxy restart -h  #just show help tips
]]

function _M.execute(origin_args)
    logger:info("Stop orProxy server...")
    pcall(stop_cmd.execute, origin_args)

    logger:info("Start orProxy server...")
    pcall(start_cmd.execute,origin_args)
end


return _M
