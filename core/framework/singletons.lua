---
---
--- worker singleton object holder, shard by worker
--- Author: Jacobs Lei
--- Date: 2018/7/3
--- Time: 下午3:33

---
-- @field worker_events
--
local _M = {
    -- loaded into worker's plugins information
    loaded_plugins = nil,

    -- loaded into worker's upstream server nodes information
    upstream_servers = {},

    upstream_round_robin_index = 1,
}

return _M