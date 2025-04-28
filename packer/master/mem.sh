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

# Get I/O Wait
IO_WAIT=$(iostat | awk 'NR==4 {print $5}')

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

MEMORY_TOTAL=$(free -m | awk 'NR==2 {print $2}')
MEMORY_USED=$(free -m | awk 'NR==2 {print $3}')
MEMORY_FREE=$(free -m | awk 'NR==2 {print $4}')

# Get the PID of the placemark process
PLACEMARK_PID=$(pgrep -f "node /home/ec2-user/placemark/node_modules/.bin/nodemon src/server.js")

if [ -n "$PLACEMARK_PID" ]; then
  # Get CPU usage of the placemark process
  PLACEMARK_CPU=$(ps -o %cpu= -p $PLACEMARK_PID | awk '{print $1}')

  # Get memory usage of the placemark process
  PLACEMARK_MEM=$(ps -o %mem= -p $PLACEMARK_PID | awk '{print $1}')

  # Push placemark-specific metrics to CloudWatch
  aws cloudwatch put-metric-data --metric-name placemark-cpu-usage \
    --dimensions Instance=$INSTANCE_ID \
    --namespace "Custom" --value $PLACEMARK_CPU --region "us-east-1"

  aws cloudwatch put-metric-data --metric-name placemark-memory-usage \
    --dimensions Instance=$INSTANCE_ID \
    --namespace "Custom" --value $PLACEMARK_MEM --region "us-east-1"
else
  echo "Placemark process not found" >> /tmp/cron_log
fi

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

aws cloudwatch put-metric-data --metric-name io-wait \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $IO_WAIT --region "us-east-1"

aws cloudwatch put-metric-data --metric-name cpu-usage \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $CPU_USAGE --region "us-east-1"

aws cloudwatch put-metric-data --metric-name memory-total \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $MEMORY_TOTAL --region "us-east-1"

aws cloudwatch put-metric-data --metric-name memory-used \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $MEMORY_USED --region "us-east-1"

aws cloudwatch put-metric-data --metric-name memory-free \
  --dimensions Instance=$INSTANCE_ID \
  --namespace "Custom" --value $MEMORY_FREE --region "us-east-1"