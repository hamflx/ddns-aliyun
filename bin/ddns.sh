#!/bin/bash

function log () {
    if [[ "$1" == "ERROR" ]]; then
        echo "$(date) [$1]: $2" >&2
    else
        echo "$(date) [$1]: $2"
    fi
}

. /etc/ddns/ddns.conf

# 从阿里云获取域名解析记录
RECORD="$($ALIYUN_BIN alidns $ALIYUN_OPTIONS DescribeSubDomainRecords --SubDomain $RECORD_RR.$RECORD_DOMAIN | jq -r '.DomainRecords.Record[0]' 2>/dev/null)"
# 从域名信息中提取 RecordId
RECORD_ID="$(echo $RECORD | jq -r .RecordId 2>/dev/null | grep -P '^\d+$')"
# 从解析记录中提取现有的记录值
PREVIOUS_IP="$(echo $RECORD | jq -r .Value 2>/dev/null | grep -P '^\d+\.\d+\.\d+\.\d+$')"

# 检查 RECORD_ID 是否有效
if [[ "$RECORD_ID" == "" ]]; then
    log ERROR "Invalid RECORD_ID: $RECORD_ID"
    exit 1
fi

# 检查 PREVIOUS_IP 是否有效
if [[ "$PREVIOUS_IP" == "" ]]; then
    log ERROR "Invalid PREVIOUS_IP: $PREVIOUS_IP"
    exit 1
fi

while true; do
    # 从公共平台查询公网 IP 地址作为拨号连接获得的 IP 地址
    PUBLIC_IP="$(curl https://ip.cn 2>/dev/null | jq -r .ip 2>/dev/null | grep -P '^\d+\.\d+\.\d+\.\d+$')"

    # 检查获取到的地址是否有效
    if [[ "$PUBLIC_IP" == "" ]]; then
        log ERROR "Invalid PUBLIC_IP: $PUBLIC_IP"
        exit 1
    fi

    # 若查询到的 IP 地址与记录比匹配则更新
    if [[ "$PREVIOUS_IP" != "$PUBLIC_IP" ]]; then
        $ALIYUN_BIN alidns $ALIYUN_OPTIONS UpdateDomainRecord --RecordId $RECORD_ID --RR $RECORD_RR --Type A --Value $PUBLIC_IP --Line default >/dev/null 2>&1

        if [[ $? -ne 0 ]]; then
            log ERROR "The aliyun cli returned an error"
            exit 1
        fi

        # 更新保存的
        PREVIOUS_IP="$PUBLIC_IP"

        log INFO "Updated successfully"
    else
        log INFO "Already latest"
    fi

    sleep $QUERY_INTERVAL
done
