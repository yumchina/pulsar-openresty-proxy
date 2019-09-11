# Apache Pulsar's Openresty proxy

## What's pulsar-openresty-proxy

Pulsar-openresty-proxy is a kind Pulsar proxy depending openresty, discovery upstream pulsar brokers from pulsar zookeeper server by balancer_by_lua.

## Code structure
- bin: OrProxy program's bin module,For start, stop, reload, restart command.
- core: core program module
- plugin: implemented plugin's handlers
- lib: depended OpenResty library
- profile:configuration profile file

## WIKI
[How to use pulsar openresty proxy](https://github.com/yumchina/pulsar-openresty-proxy/wiki)


