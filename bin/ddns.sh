#!/bin/bash

function log () {
    if [[ "$1" == "ERROR" ]]; then
        echo "$(date) [$1]: $2" >&2
    else
        echo "$(date) [$1]: $2"
    fi
}

CONFIGURATION_DIR="$HOME/.ddns"
CONFIGURATION_FILE="$HOME/.ddns/ddns.conf"
ALIYUN_CONFIG_FILE="$HOME/.ddns/aliyun.json"

if [[ ! -f "$CONFIGURATION_FILE" ]]; then
    echo "Configuration file $CONFIGURATION_FILE not found."
    exit 1
fi

. "$CONFIGURATION_FILE"

# 将配置文件中的 AccessKey 写入到阿里云的配置文件
sed -i -e "s/\"access_key_id\": \"[^\"]*\"/\"access_key_id\": \"$ACCESS_KEY_ID\"/g" \
    -e "s/\"access_key_secret\": \"[^\"]*\"/\"access_key_secret\": \"$ACCESS_KEY_SECRET\"/g" "$ALIYUN_CONFIG_FILE"

# 将配置文件路径传入阿里云 CLI
ALIYUN_OPTIONS="$ALIYUN_OPTIONS"" --config-path ""$ALIYUN_CONFIG_FILE"
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
    PUBLIC_IP="$(curl -s cip.cc | sed 's/\s\+//g' | grep -oP 'IP:\d+\.\d+\.\d+\.\d+' | cut -d ':' -f 2)"

    # 检查获取到的地址是否有效
    if [[ "$PUBLIC_IP" == "" ]]; then
        log ERROR "Invalid PUBLIC_IP: $PUBLIC_IP"
        exit 1
    else
        log INFO "Queried public ip address: ${PUBLIC_IP}"
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
