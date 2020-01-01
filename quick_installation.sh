#!/usr/bin/env bash

# Install dependencies
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install dependencies'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
yum install -y pcre-devel openssl-devel gcc

# Add yum repo
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to config yum repo'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
yum -y install yum-utils
yum-config-manager --add-repo https://openresty.org/package/rhel/openresty.repo

# Install Openresty
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install openresty'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
wget https://openresty.org/download/openresty-1.11.2.3.tar.gz
tar -xzvf openresty-1.11.2.3.tar.gz
cd openresty-1.11.2.3/

./configure --prefix="/usr/local/openresty/" \
--with-luajit \
--without-http_redis2_module \
--with-http_iconv_module \
--with-pcre-jit \
--with-ipv6 \
--with-http_realip_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_v2_module
make
make install
ln -sf /usr/local/openresty/bin/resty /usr/local/bin/resty
ln -sf /usr/local/openresty/bin/openresty /usr/local/bin/openresty
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx
cd ..

# Verify Openresty Installation
nginx -v
resty -v
openresty -v

# Install luarock
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install luarock'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
wget http://luarocks.github.io/luarocks/releases/luarocks-3.2.1.tar.gz
tar -xzf luarocks-3.2.1.tar.gz
cd luarocks-3.2.1/
./configure --prefix="/usr/local/openresty/luajit" \
--with-lua="/usr/local/openresty/luajit" \
--lua-suffix=jit \
--with-lua-include="/usr/local/openresty/luajit/include/luajit-2.1" \
--with-lua-lib="/usr/local/openresty/luajit/lib/"
make build
make install
ln -sf /usr/local/openresty/luajit/bin/luarocks /usr/local/bin/luarocks
cd ..

# Install luafilesystem by luarocks
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install luafilesystem'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
luarocks install luafilesystem

# Install orProxy
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install orProxy'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
make install
