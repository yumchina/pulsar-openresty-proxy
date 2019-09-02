# Apache Pulsar's Openresty proxy

## What's pulsar-openresty-proxy

Pulsar-openresty-proxy is a kind Pulsar proxy depending openresty, discovery upstream pulsar brokers from pulsar zookeeper server by balancer_by_lua.

## Code structure
- Makefile 安装文件
- bin OrProxy program's bin module,For start, stop, reload, restart command.
- core core program module
- plugin implemented plugin's handlers
- lib depended OpenResty library
- profile meta-configuration split by environment profile

## WIKI
[如何使用pulsar openresty proxy](https://git.tp.hwwt2.com/opensources/pulsar-openresty-proxy-v2/wiki)


