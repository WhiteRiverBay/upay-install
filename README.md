# upay-release

## 介绍

<img src="https://github.com/WhiteRiverBay/upay-ui/blob/main/public/logo.png?raw=true" alt="upay" title="upay" width="100px" height="100px" />

upay是一个自托管的在线usdt收款系统。系统为每个用户生成单独的收款地址。 

用户转账或者扫码完成支付。

upay带资金归集组件，由管理本地手动归集资金。

目前支持ethereum, bsc, base, polygon pos, arb one等evm公链，也支持tron公链。

**docker repository目前需要授权才可访问，测试完备后会公开，敬请等待**

*考虑到tron高昂的转账手续费（网络对转u收取的trx费用，等值大约2～6u，即使使用了能量机制也远高于各类evm 链），不建议使用该系统收取大量分散的小额资金，因为归集损耗较大，而且用户支付的成本也较高* 

## 主要组件

### upay-ui

upay的前端页面。[click here](https://github.com/WhiteRiverBay/upay-ui)

### upay-api

目前支持ethereum, bsc, base, polygon pos, arb one等evm公链，也支持tron公链。
 
upay服务端通过对链上usdt合约监听、交易结果监控和交易信息自动比对来完成入账和订单支付。
服务端提供交易信息丢失后的异常处理。 即用户支付系统未收到，通过提交交易哈希即可找回。

upay使用了rsa4096和aes-gcm-256来完成充值地址的私钥加密。 加密私钥和数据物理隔离。

upay提供了telegram的接口，在收到充值资金时会有通知提醒。

具体的使用方法请参见：集成开发文档 sdk下载

### upay-cli

提供充值钱包批量导出（需要ga验证码）、充值钱包地址余额扫描、手续费空投和批量资金归集功能。
安装方法：

```shell
npm i -g upay-cli
```

安装后调用

```shell
upay help
```

确认是否安装成功。

## 如何安装upay-api

### 1、安装mysql服务器，配置用户名密码，没有特殊配置，不赘述

### 2、安装redis服务器，建议配置密码、tls、证书, 如果不需要tls和密码验证，可以跳过这部分

```shell
sudo dnf install -y redis6
```

以下是自签证书的说明：

生成一个redis-cert.conf配置文件，内容如下

```text
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
C  = CA
ST = BC
L  = VAN
O  = WRB
OU = WRB TECH
CN = xredis

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = xredis.yourhost.com
DNS.2 = xredis
```

以上内容根据实际情况修改，这个文件用于自签证书


```shell
# 生成服务端证书
openssl req -new -nodes -out redis.csr -newkey rsa:2048 -keyout redis.key -config redis-cert.conf
```

```shell
# 生成根证书 - 如果自签的话
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -days 3650 -out ca.crt -config redis-cert.conf
```

```shell
# 签名服务端证书
openssl x509 -req -in redis.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out redis.crt -days 3650 
```

以上可以得到 redis.key、redis.crt和ca.key, ca.crt文件. 修改redis配置：

```text
# 启用 TLS 和端口设置
tls-port 6379
# 禁用非 TLS 端口
port 0  

# 证书和密钥文件
tls-cert-file /etc/redis6/redis.crt
tls-key-file /etc/redis6/redis.key
tls-ca-cert-file /etc/redis6/ca.crt

# 启用客户端证书验证
tls-auth-clients yes

# 配置redis，设置登录验证
requirepass 123456

# 绑定所有网口
bind * -::*

```

设置权限

```shell
# 设置权限：

sudo chown redis6:redis6 /etc/redis6/redis.crt /etc/redis6/redis.key /etc/redis6/ca.crt 
sudo chmod 600 /etc/redis6/redis.key
sudo chmod 644 /etc/redis6/redis.crt /etc/redis6/ca.crt

# 编写启停脚本：
sudo systemctl restart redis6
```
-------------

接下来生成客户端证书

编辑client.conf, 写入以下内容，根据实际情况调整

```text
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = dn

[ dn ]
C  = CA
ST = BC
L  = VAN
O  = WRB
OU = WRB TECH
CN = *.xnode.xrocket.network

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.yourhost.com
DNS.2 = example
```

```shell
# 支持泛域名，生成客户端证书
openssl req -new -nodes -out client.csr -newkey rsa:2048 -keyout client.key -config client.conf

# 使用ca根证书签署客户端证书
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650 

# 合并成为p12
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt
```

然后执行以下命令，将相关的客户端证书放入客户端配置中

```shell
cp ca.crt .config/
cp client.p12 .config/
```

### 3 初始化数据库

将 init_mysql.sql 导入第一步创建的数据库中。

### 4 初始化系统

```shell
sh init.sh
```

根据提示配置系统，配置完成后，调用

```shell
sudo docker-compose up -d
```

启动系统

第一次启动时候可以不用 -d参数，来观察日志输出是否有报错，如果有报错，根据错误信息排除障碍。


## 如何安装upay-ui

upay-ui做了移动端自适应，也可以嵌套在webview里。
如果在webview里用，请在userAgent里增加UPayInApp字符串，并在app里监控popPage调用。 （目前只支持flutter_inappwebview）

fork ui代码，修改api接口，直接部署到cf或者github即可。
如果想要放在自己的服务器上，执行

```shell
npm run build:prod
```

然后部署dist目录即可。


## 如何使用upay-cli

### 1 获取管理脚本

### 2 一键归集脚本

### 3 查看归集汇总数据

### 空投合约地址

evm(eth, base, bsc, arb one, polygon)：0xE9511e55d2AaC1F62D7e3110f7800845dB2a31F1
tron：TNnHipM7aZMYYanXhESgRV9NmjndcgvaXu

