## SDK

[sdk, preparing...](https://github.com/WhiteRiverBay/upay-sdk)

## REST API

### security 接口验证摘要算法：

0 生成两个额外的字段：timestamp和nonce，一个是毫秒数，一个是一次性随机字符串
1 将所有的参数按照字典进行排序
2 排序后的参数按照k=v的格式，使用‘&’ 连接起来
3 在字符串尾部增加配置前面的数字配置摘要secret
4 使用sha256hex进行摘要，将摘要后的数据追加sign字段

样例代码

```php
# php version
public function sign($data) {
    ksort($data);
    $str = '';

    // join $data with $key=$value&$key=$value
    foreach ($data as $key => $value) {
        $str .= $key . '=' . $value . '&';
    }
    //remove the last &
    $str = substr($str, 0, -1);
    $str .= $this->config['app_secret'];
    // sha256
    return hash('sha256', $str);
}
```

```java
// java
Map<String, Object> params = new TreeMap<>();
// TODO params.addAll(allParameters);
String base = MapUtil.join(params, "&", "=", true);
String _sign = DigestUtil.sha256Hex(base + System.getenv("PAYMENT_NOTIFY_SECRET"));
```

### 1 创建收款单 （需验证）

POST /api/v1/order

content type: application/json
json body content:
```json
{
    "oid": "1",
    "uid": "1", // user's id 
    "amount": "100", // 100 usdt
    "memo": "the memo of the order",
    "expiredAt": 109000000000,  //timestamp of expiration, in ms
    "timestamp": 109000000000,
    "nonce": "asdasdfasdfasdfasdf",
    "mchId": "1",
    "notifyUrl": "https://test.com/backend/notify",
    "redirectUrl": "https://frontend.test.com/success.html"
}
```

PHP Code:

```php
$expire = 3600;
$data = [
    'oid' => $order['trade_no'],
    'uid' => $order['user_id'],
    'amount' => sprintf('%.2f', $order['total_amount'] / 100),
    'memo' => 'Test memo',
    'expiredAt' => (time() + $expire) * 1000,
    'timestamp' => time() * 1000,
    'nonce' => rand(10000000, 99999999),
    'mchId' => '1',
    'notifyUrl' => 'https://test.com/backend/notify',
    'redirectUrl' => 'https://frontend.test.com/success.html'
];
$data['sign'] = sign($data);
$url = $upayEndpoint . '/api/v1/order';
$response = post($url, $data);
// if not 200
if (empty($response)) {
    throw new Exception('request error');
}

$resp = json_decode($response, true);
if ($resp['code'] != 1) {
    throw new Exception($resp['msg']);
}
$jumpUrl ='https://upay.test.com/?id=' . $resp['data']['id'];

// send 301 jumpUrl
```

shell code

```shell
#!/bin/bash

API=http://localhost:8080/api/v1/order

now=$(date +"%s")
nowInMs=$(($now * 1000))
expireAt=$((($now + 86400) * 1000))
nonce=$(date +"%s%S")

uid=1
oid=$1
amount=1
memo=test-memo-1
mchId=1
secret=thesecret

base="amount=$amount&expiredAt=$expireAt&mchId=$mchId&memo=$memo&nonce=$nonce&oid=$oid&timestamp=$nowInMs&uid=$uid$secret"

sign=$(printf $base | openssl dgst -sha256 | awk '{print $2}')

data='{
    "oid": "'$oid'",
    "uid": "'$uid'",
    "amount": "'$amount'",
    "memo": "'$memo'",
    "expiredAt": '$expireAt',
    "timestamp": '$nowInMs',
    "mchId": "'$mchId'",
    "nonce": "'$nonce'",
    "sign": "'$sign'",
    "callbackUrl": "'$callbackUrl'"
}'
curl -X POST $API -H "Content-Type: application/json" -d "$data" | jq .
```

### 2 跳转到收款页面

创建订单后，使用订单号跳转到特定页面，引导用户完成支付。

### 3 收款成功通知

upay会将交易结果数据通过post提交到订单预设的notify url。如果首次通知失败的话，会持续通知24个小时，直到业务系统的接口返回success字符串。

**请对回调的数据的摘要做校验**
**做去重，避免反复回调产生重复的支付数据**

以下是一个php处理回调通知的示例代码：

```php
$payload = trim(get_request_content());
if (empty($payload)) {
    throw new ApiException('request error');
}

$json_params = json_decode($payload, true);

$data = [
    'id' => $json_params['id'],
    'oid' => $json_params['oid'],
    'uid' => $json_params['uid'],
    'timestamp' => $json_params['timestamp'],
    'nonce' => $json_params['nonce'],
    'status' => $json_params['status'],
    'statusCode' => $json_params['statusCode']
];

$sign = $this->sign($data);
if ($sign != $json_params['sign']) {
    throw new ApiException('sign error');
}

if ($json_params['status'] == 'PAID') {
    // ORDER PAID
    return true;
}
```

### 4 主动查询订单状态

GET /api/v1/order/{id}/status

id是create order时候返回的交易单id，非业务系统订单id

### 5 退款

POST /api/v1/refund

```shell
# id or oid 
data='{
    "id": "'$id'", 
    "oid": "'$oid'",
    "amount": "'$amount'",
    "remark": "'$remark'",
    "timestamp": '$nowInMs',
    "nonce": "'$nonce'",
    "sign": "'$sign'",
}'
curl -X POST http://localhost:8080/api/v1/refund -H "Content-Type: application/json" -d "$data"
```

### 6 扣款接口 - 用于对接提现系统

```shell
POST /api/v1/balance/minus
```
