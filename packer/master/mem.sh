#!/bin/bash

# Verify cron is running
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo "$CURRENT_TIME" >> /tmp/cron_log

# Get the instance metadata token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get the instance ID
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# Get memory usage
USEDMEMORY=$(free -m | awk 'NR==2 {printf "%.2f", $3*100/$2 }')

# Get total TCP connections
TCP_CONN=$(netstat -an | wc -l)

# Get TCP connections on port 80
TCP_CONN_PORT_80=$(netstat -an | grep ':80' | wc -l)

# Push metrics to CloudWatch
aws cloudwatch put-metric-data --metric-name memory-usage \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $USEDMEMORY --region "us-east-1"

aws cloudwatch put-metric-data --metric-name Tcp_connections \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $TCP_CONN --region "us-east-1"

aws cloudwatch put-metric-data --metric-name TCP_connection_on_port_80 \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $TCP_CONN_PORT_80 --region "us-east-1"