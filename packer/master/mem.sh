#!/bin/bash

# Verify cron is running
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "$CURRENT_TIME" >> /tmp/cron_log

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

USEDMEMORY=$(free -m | awk 'NR==2 {printf "%.2f", $3*100/$2 }')

TCP_CONN=$(netstat -an | wc -l)

TCP_CONN_PORT_80=$(netstat -an | grep ':80' | wc -l)


aws cloudwatch put-metric-data --metric-name memory-usage \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $USEDMEMORY

aws cloudwatch put-metric-data --metric-name Tcp_connections \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $TCP_CONN

aws cloudwatch put-metric-data --metric-name TCP_connection_on_port_80 \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $TCP_CONN_PORT_80
