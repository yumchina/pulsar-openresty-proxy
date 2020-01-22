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

    init_by_lua_block {
        local app = require("core.main")
        local global_config_path = "${{conf_path}}"
        local config,prometheus_metrics = app.init(global_config_path)

        --application context
        context = {
            app = app,
            config = config,
            prometheus_metrics = prometheus_metrics

        }
    }

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
                context.prometheus_metrics:metrics()
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

}
]]
