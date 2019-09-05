local _M = {}

-- 插件名称
_M.plugin_name = "zk_dynamic_upstream"


-- retries count configuration information property's store key
_M.balance_retries_count_key = "BALANCE_RETRIES_COUNT"
_M.balance_connection_timeout_key = "BALANCE_CONNECTION_TIMEOUT"
_M.balance_send_timeout_key =  "BALANCE_SEND_TIMEOUT"
_M.balance_read_timeout_key = "BALANCE_READ_TIMEOUT"

_M.upstream_zk_register_path = "/loadbalance/brokers"

_M.small_error_types = {
    sys =  {
        type_balancer_execute_error = _M.plugin_name .. ".balancer_execute_error"
    },
    biz = {
        type_service_not_found = _M.plugin_name .. ".no_service",
        type_req_method_not_support = _M.plugin_name .. ".med_not_support",
        type_no_available_balancer = _M.plugin_name ..".no_available_balancer"
    }
}




return _M