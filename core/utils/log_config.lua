---
--- log config, such as log level & format and so on.
--- Created by Jacobs Lei.
--- DateTime: 2018/11/13 下午3:05
---

local _M={}

_M.INFO = "info";
_M.ERROR = "error";
_M.WARN = "warn";
_M.sys_error_format = "[system-%s]-%s"
_M.biz_error_format = "[business-%s]-%s";

return _M;