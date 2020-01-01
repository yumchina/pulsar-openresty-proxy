# Apache Pulsar's Openresty proxy


[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/yumchina/pulsar-openresty-proxy/blob/master/LICENSE) [![Version](https://img.shields.io/github/v/release/yumchina/pulsar-openresty-proxy)](https://github.com/yumchina/pulsar-openresty-proxy/releases)

## What's pulsar-openresty-proxy

Pulsar-openresty-proxy is a kind of [Apache Pulsar](https://github.com/apache/pulsar) proxy depending openresty, discovery upstream pulsar brokers from pulsar zookeeper server by balancer_by_lua.

## Code structure
- bin: OrProxy program's bin module,For start, stop, reload, restart command.
- core: core program module
- plugin: implemented plugin's handlers
- lib: depended OpenResty library
- profile:configuration profile file

## Install && Usages && Config
- [How to install](https://github.com/yumchina/pulsar-openresty-proxy/wiki)
- [How to configure](https://github.com/yumchina/pulsar-openresty-proxy/wiki/Configuration-File-sample)
- [How to run](https://github.com/yumchina/pulsar-openresty-proxy/wiki/Pulsar-Openresty-Proxy-Command-Instruction)


## License
[Apache 2.0](./LICENSE)


## See also

The plugin architecture is highly inspired by [Kong](https://github.com/Mashape/kong).


