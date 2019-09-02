--- define cache prefix for using ngx.dict
--- @author Jacobs Lei
--- @since 2019-06-17

local prefix = {}

--- API_CONTEXT配置数据前缀
prefix.api_group = "API_GROUP_"


--- 同一HOST下所有API_CONTEXT集合数据前缀
prefix.host_api_group_context = "HOST_API_GROUP_CONTEXT_"

--- 插件配置数据前缀
prefix.plugin = "PLUGIN_"

--- 全局属性配置数据前缀
prefix.global_property = "GLOBAL_PROPERTY_"

--- API组限速配置数据前缀
prefix.api_group_rate_limit = "API_GROUP_RATE_LIMIT_"


--- 防火墙配置数据前缀
prefix.waf = "WAF_"

---限速配置数据前缀
prefix.rate_limit = "RATE_LIMIT_"


--- 选择器配置数据前缀
prefix.selector = "SELECTOR_"


---  round robin current index key
prefix.balancer_current_round_robin_index = "GLOBAL_CACHE_KEY_CURRENT_ROUND_ROBIN_INDEX"

return prefix