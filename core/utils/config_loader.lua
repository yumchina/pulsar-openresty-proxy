local cjson = require("core.utils.json")
local IO = require "core.utils.io"
local ngx = ngx

local _M = {}

local env_conf_path = os.getenv("ORPROXY_CONF_PATH")

_M.default_conf_path = env_conf_path or ngx.config.prefix() .."/conf/orProxy.json"

function _M.load(config_path)
    config_path = config_path or _M.default_conf_path
    local config_contents = IO.read_file(config_path)

    if not config_contents then
        ngx.log(ngx.ERR, "No configuration file at: ", config_path)
        os.exit(1)
    end
    --ngx.log(ngx.INFO, "OrProxy Server meta configuration data: ", config_contents)
    local config = cjson.decode(config_contents)
    return config, config_path
end

return _M