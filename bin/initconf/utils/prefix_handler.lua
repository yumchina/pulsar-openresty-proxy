local nginx_template = require "bin.initconf.templates.nginx"
local pl_template = require "pl.template"
local pl_tablex = require "pl.tablex"
local pl_file = require "pl.file"
local pl_path = require "pl.path"
local pl_dir = require "pl.dir"
local logger = require "bin.utils.logger"

local _M = {}

local function compile_conf(orProxy_config, conf_template)
  -- computed config properties for templating
  local compile_env = {
    _escape = ">",
    pairs = pairs,
    tostring = tostring
  }

  compile_env = pl_tablex.merge(compile_env, orProxy_config, true) -- union
  if compile_env.dns_resolver then
    compile_env.dns_resolver = table.concat(compile_env.dns_resolver, " ")
  end


  local post_template, err = pl_template.substitute(conf_template, compile_env)

  if not post_template then
    return nil, "failed to compile nginx config template: " .. err
  end
  local value = string.gsub(post_template, "(${%b{}})", function(w)
    local name = w:sub(4, -3)
    local tb = compile_env[name:lower()] or ""
    return tb
  end)
  return value
end

local function compile_orProxy_conf(orProxy_config)
  return compile_conf(orProxy_config, nginx_template)
end

function _M.prepare_prefix(orProxy_config)

  if not pl_path.exists(orProxy_config.prefix) then
    logger:info("Prefix directory %s not found, trying to create it", orProxy_config.prefix)
    local ok, err = pl_dir.makepath(orProxy_config.prefix)
    if not ok then
      return false, err
    end

  elseif not pl_path.isdir(orProxy_config.prefix) then
    return false, orProxy_config.prefix .. " is not a directory"
  end

  -- create logs directory
  local logs_path = orProxy_config.prefix .. "/logs"
  if not pl_path.exists(logs_path) then
    logger:info("logs directory %s not found, trying to create it", logs_path)
    local ok, err = pl_dir.makepath(logs_path)
    if not ok then
      return false, err
    end
  end

  -- create pids directory
  local pids_path = orProxy_config.prefix .. "/pids"
  if not pl_path.exists(pids_path) then
    logger:info("pids directory %s not found, trying to create it", pids_path)
    local ok, err = pl_dir.makepath(pids_path)
    if not ok then
      return false, err
    end
  end


  -- write OrProxy's NGINX conf
  local nginx_conf, err = compile_orProxy_conf(orProxy_config)
  if not nginx_conf then
    return false, err
  end
  logger:info("Generating nginx.conf from %s.", orProxy_config.conf_path)
  pl_file.write(orProxy_config.nginx_conf, nginx_conf)
  return true
end
return _M
