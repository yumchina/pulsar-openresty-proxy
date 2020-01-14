return [[
worker_processes ${{worker_processes_count}};
worker_rlimit_nofile ${{worker_rlimit}};
daemon on;
pid pids/nginx.pid;
events {
    use ${{event_mode}};
    worker_connections  ${{worker_connections}};
    multi_accept on;
}

http {
    include   'mime.types';
    default_type  application/octet-stream;
    charset UTF-8;

    keepalive_timeout 75;
    keepalive_requests 8192;

    server_tokens off;
    large_client_header_buffers 4 256k;
    client_max_body_size 300m;
    client_body_buffer_size 16m;
    server_names_hash_bucket_size 64;

    sendfile	on;
    tcp_nodelay on;
    #tcp_nopush on;             # disabled until benchmarked
    proxy_buffer_size 1600k;    # disabled until benchmarked
    proxy_buffers 4 3200k;      # disabled until benchmarked
    proxy_busy_buffers_size 6400k; # disabled until benchmarked
    proxy_temp_file_write_size 6400k;
    proxy_max_temp_file_size 128m;

    #reset_timedout_connection on; #disabled until benchmarked

    proxy_connect_timeout      600;
    #后端服务器数据回传时间(代理发送超时)
    proxy_send_timeout         600;
    #连接成功后，后端服务器响应时间(代理接收超时)
    proxy_read_timeout         600;

    gzip	on;
    gzip_min_length 1k;
    gzip_buffers 16 64k;
    gzip_http_version 1.1;
    gzip_comp_level 6;
    gzip_types text/plain application/x-javascript application/javascript text/javascript text/css application/xml;
    gzip_vary on;

    map $http_upgrade $connection_upgrade {
        default Upgrade;
        ''      close;
    }

    #dtest
    #max_ranges 1;
> if real_ip_header then
    real_ip_header     ${{REAL_IP_HEADER}};
> end
>if real_ip_recursive then
    real_ip_recursive  ${{REAL_IP_RECURSIVE}};
> end
>if trusted_ips then
> for i = 1, #trusted_ips do
    set_real_ip_from   $(trusted_ips[i]);
> end
>end

    #Access Log日志格式
    log_format main '$proxy_add_x_forwarded_for||$remote_user||$time_local||$request||$status||$body_bytes_sent||$http_referer||$http_user_agent||$remote_addr||$http_host||$request_body||$upstream_addr||$request_time||$upstream_response_time||$trace_id||$request_headers';

    log_format non-body '$proxy_add_x_forwarded_for||$remote_user||$time_local||$request||$status||$body_bytes_sent||$http_referer||$http_user_agent||$remote_addr||$http_host||-||$upstream_addr||$request_time||$upstream_response_time||$trace_id||-';

> if access_log then
    access_log  ${{ACCESS_LOG}}  main;
> end
> if error_log then
    error_log ${{ERROR_LOG}} ${{LOG_LEVEL}};
> end

    #是否允许在header的字段中带下划线
    underscores_in_headers on;

    lua_package_path '${{prefix}}/?.lua;${{prefix}}/lib/?.lua;;';
    lua_package_cpath '${{prefix}}/?.so;;';
    lua_socket_pool_size ${{LUA_SOCKET_POOL_SIZE}};
    lua_socket_keepalive_timeout 30s;
    lua_socket_log_errors off;

    #最大同时运行任务数
    lua_max_running_timers ${{LUA_MAX_RUNNING_TIMERS}};

    #最大等待任务数
    lua_max_pending_timers ${{LUA_MAX_PENDING_TIMERS}};

    lua_shared_dict prometheus_metrics 100M;

> if wk_global_cache_dict_size then
    #全局缓存字典定义
    lua_shared_dict wk_global_cache ${{WK_GLOBAL_CACHE_DICT_SIZE}};
> end


>if wk_lock_dict_size then
    #for resty lock
    lua_shared_dict wk_lock ${{WK_LOCK_DICT_SIZE}};
> end

> if dns_resolver then
    #根据实际内网DNS地址情况设置;dns 结果缓存时间, DNS resolver 服务数组轮询使用，务必保证每个dns resolver都可用
    resolver ${{DNS_RESOLVER}} valid=${{DNS_RESOLVER_VALID}} ipv6=off;

    #dns 解析超时时间
    resolver_timeout ${{RESOLVER_TIMEOUT}};
> end
    #代码缓存 生产环境打开
    lua_code_cache ${{LUA_CODE_CACHE}};

>if service_type == "gateway_service" then

    upstream default_upstream {
        server 0.0.0.1;
        balancer_by_lua_block {
            local app = context.app
            app.balancer()
        }
>if upstream_keepalive then
        keepalive ${{UPSTREAM_KEEPALIVE}};
>end
    }
>end

    init_by_lua_block {
        local app = require("core.main")
        local global_config_path = "${{conf_path}}"
        local config = app.init(global_config_path)

        --application context
        context = {
            app = app,
            config = config
        }

        prometheus = require("prometheus").init("prometheus_metrics")
        local bucket =  {0.01, 0.05, 0.1, 0.5, 1, 5}
        http_requests = prometheus:counter(
            "nginx_http_requests", "Number of HTTP requests", {"host", "status"})
        http_request_time = prometheus:histogram(
            "nginx_http_request_time", "HTTP request time", {"host"}, bucket)
        http_request_bytes_received = prometheus:counter(
            "nginx_http_request_bytes_received", "Number of HTTP request bytes received", {"host"})
        http_request_bytes_sent = prometheus:counter(
            "nginx_http_request_bytes_sent", "Number of HTTP request bytes sent", {"host"})
        http_connections = prometheus:gauge(
            "nginx_http_connections", "Number of HTTP connections", {"state"})
        http_upstream_cache_status = prometheus:counter(
            "nginx_http_upstream_cache_status", "Number of HTTP upstream cache status", {"host", "status"})
        http_upstream_requests = prometheus:counter(
            "nginx_http_upstream_requests", "Number of HTTP upstream requests", {"addr", "status"})
        http_upstream_response_time = prometheus:histogram(
            "nginx_http_upstream_response_time", "HTTP upstream response time", {"host", "addr"}, bucket)
        http_upstream_header_time = prometheus:histogram(
            "nginx_http_upstream_header_time", "HTTP upstream header time", {"host", "addr"}, bucket)
         http_upstream_bytes_received = prometheus:counter(
            "nginx_http_upstream_bytes_received", "Number of HTTP upstream bytes received", {"addr"})
        http_upstream_bytes_sent = prometheus:counter(
            "nginx_http_upstream_bytes_sent", "Number of HTTP upstream bytes sent", {"addr"})
        http_upstream_connect_time = prometheus:histogram(
            "nginx_http_upstream_connect_time", "HTTP upstream connect time", {"host", "addr"}, bucket)
        http_upstream_first_byte_time = prometheus:histogram(
            "nginx_http_upstream_first_byte_time", "HTTP upstream first byte time", {"host", "addr"}, bucket)
        http_upstream_session_time = prometheus:histogram(
            "nginx_http_upstream_session_time", "HTTP upstream session time", {"host", "addr"}, bucket)
    }


>if service_type == "gateway_service" then
    init_worker_by_lua_block {
        local app = context.app
        app.initWorker()
    }

    # default server handling illegal hostname  request
    server {
        listen 80 default_server;
        server_name _ ;

        access_log /var/log/orProxy/default.access.log main;
        error_log /var/log/orProxy/default.error.log warn;

        location /  {
           default_type application/json;
           return 444 '{"error":"hostname is illegal."}';
        }
        location = /health/ping {
            content_by_lua_block {
                local cjson = require("core.utils.json")
                local server_info = require("core.server_info")
                local resp = {}

                resp["status"] = "up"
                resp["server"] = server_info.full_name
                ngx.header["Server"] = server_info.full_name
                ngx.header["Content-Type"] = "application/json; charset=utf-8"
                ngx.say(cjson.encode(resp))
                ngx.exit(ngx.HTTP_OK)
            }
        }
    }

    server {
        listen 9113;
        #allow 192.168.0.0/16;
        #deny all;
        location /metrics {
            content_by_lua_block {
                if ngx.var.connections_active ~= nil then
                    http_connections:set(ngx.var.connections_active, {"active"})
                    http_connections:set(ngx.var.connections_reading, {"reading"})
                    http_connections:set(ngx.var.connections_waiting, {"waiting"})
                    http_connections:set(ngx.var.connections_writing, {"writing"})
                end
                prometheus:collect()
            }
        }
    }

    # ====================== gateway main server ===============
>for i = 1, #hosts_conf do
    server {

>if hosts_conf[i].listen_port then
        listen                   $(hosts_conf[i].listen_port);
>end


>if hosts_conf[i].open_ssl ~= "off" then
        listen  443 ssl;
>end

> if hosts_conf[i].access_log then
        access_log  $(hosts_conf[i].access_log)  main;
> end
> if hosts_conf[i].error_log then
        error_log $(hosts_conf[i].error_log) $(hosts_conf[i].log_level);
> end

>if hosts_conf[i].open_ssl ~= "off" then
        ssl_certificate $(hosts_conf[i].ssl_certificate);
>end
>if hosts_conf[i].open_ssl ~= "off" then
        ssl_certificate_key  $(hosts_conf[i].ssl_certificate_key);
>end
>if hosts_conf[i].host then
       server_name              $(hosts_conf[i].host);
>end

>if hosts_conf[i].proxy_intercept_errors == "on" then
        error_page $(hosts_conf[i].error_page_code) /error_handler;
        proxy_intercept_errors on;
>end

>if hosts_conf[i].include_directives then
        $(hosts_conf[i].include_directives)
>end
        location = /health/ping {
            content_by_lua_block {
                local cjson = require("core.utils.json")
                local server_info = require("core.server_info")
                local resp = {}
                resp["status"] = "up"
                resp["server"] = server_info.full_name
                 ngx.header["Server"] = server_info.full_name
                ngx.header["Content-Type"] = "application/json; charset=utf-8"
                ngx.say(cjson.encode(resp))
                ngx.exit(ngx.HTTP_OK)
            }
        }

        location / {

>if hosts_conf[i].include_def_local_directives then

> for i_def = 1, #hosts_conf[i].include_def_local_directives do
            $(hosts_conf[i].include_def_local_directives[i_def])
> end

>end

> if hosts_conf[i].non_body == "true" then
            access_log  $(hosts_conf[i].access_log) non-body;
> end
        # 不区分大写匹配,multipart media type's request body does not display in logging
        if ($content_type ~* "multipart") {
> if hosts_conf[i].access_log then
                access_log  $(hosts_conf[i].access_log) non-body;
> end
        }


>if hosts_conf[i].add_headers then
> for j = 1, #hosts_conf[i].add_headers do
            add_header $(hosts_conf[i].add_headers[j].key) $(hosts_conf[i].add_headers[j].value);
> end
>end
            set $upstream_scheme '';
            set $upstream_host   '';
            set $upstream_url   'http://default_upstream';
            set $api_router_group_id '';
            set $ctx_ref '';
            set $upstream_upgrade            '';
            set $upstream_connection         '';
            set $request_headers '-';
            set $trace_id '-';

            access_by_lua_block {
                local app = context.app

                app.access()
            }


            #proxy
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Scheme $scheme;
            proxy_set_header Host $upstream_host;

            proxy_pass_header  Server;
            proxy_pass_header  Date;
            proxy_pass $upstream_url;

>if hosts_conf[i].proxy_http_version == "1.1" then
            proxy_http_version 1.1;
            proxy_set_header   Upgrade           $upstream_upgrade;
            proxy_set_header   Connection        $upstream_connection;
>end

            proxy_redirect    off;
            #retries configure, non_idempotent method 's retry controlling in program code
>if hosts_conf[i].proxy_next_upstream then
            proxy_next_upstream $(hosts_conf[i].proxy_next_upstream);
>end
            header_filter_by_lua_block {
                local app = context.app
                app.header_filter()
            }

            body_filter_by_lua_block {
                local app = context.app
                app.body_filter()
            }

            log_by_lua_block {
                local app = context.app
                app.log()
                local function split(str)
                    local array = {}
                    for mem in string.gmatch(str, '([^, ]+)') do
                        table.insert(array, mem)
                    end
                    return array
                end
                local function getWithIndex(str, idx)
                    if str == nil then
                        return nil
                    end
                    return split(str)[idx]
                end
                local host = ngx.var.host
                local status = ngx.var.status
                http_requests:inc(1, {host, status})
                http_request_time:observe(ngx.now() - ngx.req.start_time(), {host})
                http_request_bytes_sent:inc(tonumber(ngx.var.bytes_sent), {host})
                if ngx.var.bytes_received ~= nil then
                    http_request_bytes_received:inc(tonumber(ngx.var.bytes_received), {host})
                end
                local upstream_cache_status = ngx.var.upstream_cache_status
                if upstream_cache_status ~= nil then
                    http_upstream_cache_status:inc(1, {host, upstream_cache_status})
                end
                local upstream_addr = ngx.var.upstream_addr
                if upstream_addr ~= nil then
                    local addrs = split(upstream_addr)

                    local upstream_status = ngx.var.upstream_status
                    local upstream_response_time = ngx.var.upstream_response_time
                    local upstream_connect_time = ngx.var.upstream_connect_time
                    local upstream_first_byte_time = ngx.var.upstream_first_byte_time
                    local upstream_header_time = ngx.var.upstream_header_time
                    local upstream_session_time = ngx.var.upstream_session_time
                    local upstream_bytes_received = ngx.var.upstream_bytes_received
                    local upstream_bytes_sent = ngx.var.upstream_bytes_sent
                    -- compatible for nginx commas format
                    for idx, addr in ipairs(addrs) do
                        if table.getn(addrs) > 1 then
                            upstream_status = getWithIndex(ngx.var.upstream_status, idx)
                            upstream_response_time = getWithIndex(ngx.var.upstream_response_time, idx)
                            upstream_connect_time = getWithIndex(ngx.var.upstream_connect_time, idx)
                            upstream_first_byte_time = getWithIndex(ngx.var.upstream_first_byte_time, idx)
                            upstream_header_time = getWithIndex(ngx.var.upstream_header_time, idx)
                            upstream_session_time = getWithIndex(ngx.var.upstream_session_time, idx)
                            upstream_bytes_received = getWithIndex(ngx.var.upstream_bytes_received, idx)
                            upstream_bytes_sent = getWithIndex(ngx.var.upstream_bytes_sent, idx)
                        end
                        http_upstream_requests:inc(1, {addr, upstream_status})
                        http_upstream_response_time:observe(tonumber(upstream_response_time), {host, addr})
                        http_upstream_header_time:observe(tonumber(upstream_header_time), {host, addr})
                        -- ngx.config.nginx_version >= 1011004
                        if upstream_first_byte_time ~= nil then
                            http_upstream_first_byte_time:observe(tonumber(upstream_first_byte_time), {host, addr})
                        end
                        if upstream_connect_time ~= nil then
                            http_upstream_connect_time:observe(tonumber(upstream_connect_time), {host, addr})
                        end
                        if upstream_session_time ~= nil then
                            http_upstream_session_time:observe(tonumber(upstream_session_time), {host, addr})
                        end
                        if upstream_bytes_received ~= nil then
                            http_upstream_bytes_received:inc(tonumber(upstream_bytes_received), {addr})
                        end
                        if upstream_bytes_sent ~= nil then
                            http_upstream_bytes_sent:inc(tonumber(upstream_bytes_sent), {addr})
                        end
                    end
                end
            }
        }

        location /robots.txt {
            return 200 'User-agent: *\nDisallow: /';
        }

        location = /error_handler{
            internal; #指定location只能被“内部的”请求调用
            content_by_lua_block {
                local app = context.app
                app.error_handle()
            }
            log_by_lua_block {
                local app = context.app
                app.log()
            }
        }

        #关闭favicon.ico不存在时记录日志
        location = /favicon.ico {
            log_not_found off;
            access_log off;
        }
    }
>end
>end
}
]]
