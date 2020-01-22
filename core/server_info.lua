--[[
   Apache Pulsar Openresty Proxy server's base information definition, such as version & name and so on....
   Design by YumChina's architect team.
--]]
--- @author Jacobs Lei
--- @since 2019-06-13
---
local server = {}
server.version = "1.1"
server.name="orProxy"
server.full_name = server.name .. "/" .. server.version
return server