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

secret=1234567890987654321abcdefg
notifyUrl=https://your.app.domain/upay-notify
redirectUrl=https://your.app.domain?oid=$oid

base="amount=$amount&expiredAt=$expireAt&mchId=$mchId&memo=$memo&nonce=$nonce&notifyUrl=$notifyUrl&oid=$oid&redirectUrl=$redirectUrl&timestamp=$nowInMs&uid=$uid$secret"

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
    "redirectUrl": "'$redirectUrl'",
    "notifyUrl" : "'$notifyUrl'"
}'

curl -X POST $API -H "Content-Type: application/json" -d "$data" | jq .
