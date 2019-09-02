---
---  Nginx shard dict  name's constants
--- Created by Jacobs.
--- DateTime: 2018/7/12 下午3:29
---

local _M = {

    -- Shard dict global local cache
    global_cache = "wk_global_cache",

    -- worker events shard dict
    worker_events = "wk_worker_process_events",

    -- health check shard dict
    health_check = "wk_health_checks",

    -- lock shard dict
    lock = "wk_lock",

    -- stat dashboard shard dict
    stat_dashboard = "wk_stat_dashboard_data",

    -- counter dashboard shard dict
    counter_cache = "wk_rate_limit_counter",


}

return  _M
