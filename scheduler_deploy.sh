#!/bin/bash
set -e

# Interactive input collection
read -p "Enter EC2 Instance ID (e.g., i-0abc1234def56789): " INSTANCE_ID
read -p "Enter AWS Region [default: eu-central-1]: " REGION
REGION=${REGION:-eu-central-1}
read -p "Enter instance START time (24h format, e.g., 22:30): " START_TIME
read -p "Enter instance STOP time (24h format, e.g., 07:00): " STOP_TIME

# Convert CEST to UTC time
START_HOUR_UTC=$(date -d "$START_TIME today CEST" -u +%H)
START_MIN_UTC=$(date -d "$START_TIME today CEST" -u +%M)
STOP_HOUR_UTC=$(date -d "$STOP_TIME today CEST" -u +%H)
STOP_MIN_UTC=$(date -d "$STOP_TIME today CEST" -u +%M)

START_CRON="cron(${START_MIN_UTC} ${START_HOUR_UTC} * * ? *)"
STOP_CRON="cron(${STOP_MIN_UTC} ${STOP_HOUR_UTC} * * ? *)"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating IAM role..."
aws iam create-role --role-name LambdaEC2SchedulerRole \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam attach-role-policy \
  --role-name LambdaEC2SchedulerRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
  --role-name LambdaEC2SchedulerRole \
  --policy-name EC2ControlPolicy \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ec2:StartInstances","ec2:StopInstances"],"Resource":"*"}]}'

echo "Waiting 45 seconds for IAM role propagation..."
sleep 45

echo "Creating Lambda function for EC2 instance startup..."
mkdir -p lambda_start && cd lambda_start
cat > lambda_function.py <<EOF
import boto3
def lambda_handler(event, context):
    boto3.client("ec2", region_name="${REGION}").start_instances(InstanceIds=["${INSTANCE_ID}"])
    return "Started ${INSTANCE_ID}"
EOF
zip function.zip lambda_function.py && cd ..

aws lambda create-function \
  --function-name StartEC2InstanceLambda \
  --runtime python3.12 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/LambdaEC2SchedulerRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_start/function.zip \
  --timeout 30 \
  --region ${REGION}

echo "Creating Lambda function for EC2 instance shutdown..."
mkdir -p lambda_stop && cd lambda_stop
cat > lambda_function.py <<EOF
import boto3
def lambda_handler(event, context):
    boto3.client("ec2", region_name="${REGION}").stop_instances(InstanceIds=["${INSTANCE_ID}"])
    return "Stopped ${INSTANCE_ID}"
EOF
zip function.zip lambda_function.py && cd ..

aws lambda create-function \
  --function-name StopEC2InstanceLambda \
  --runtime python3.12 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/LambdaEC2SchedulerRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_stop/function.zip \
  --timeout 30 \
  --region ${REGION}

echo "Creating EventBridge scheduling rules..."
aws events put-rule \
  --name StartEC2ViaLambdaRule \
  --schedule-expression "${START_CRON}" \
  --state ENABLED \
  --region ${REGION}

aws events put-rule \
  --name StopEC2ViaLambdaRule \
  --schedule-expression "${STOP_CRON}" \
  --state ENABLED \
  --region ${REGION}

echo "Configuring Lambda functions as EventBridge targets..."
aws events put-targets --rule StartEC2ViaLambdaRule --region ${REGION} \
  --targets "[{\"Id\":\"StartEC2Lambda\",\"Arn\":\"arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:StartEC2InstanceLambda\"}]"

aws events put-targets --rule StopEC2ViaLambdaRule --region ${REGION} \
  --targets "[{\"Id\":\"StopEC2Lambda\",\"Arn\":\"arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:StopEC2InstanceLambda\"}]"

echo "Adding EventBridge permissions to invoke Lambda functions..."
aws lambda add-permission \
  --function-name StartEC2InstanceLambda \
  --statement-id allow-eventbridge-start \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/StartEC2ViaLambdaRule \
  --region ${REGION}

aws lambda add-permission \
  --function-name StopEC2InstanceLambda \
  --statement-id allow-eventbridge-stop \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:${REGION}:${ACCOUNT_ID}:rule/StopEC2ViaLambdaRule \
  --region ${REGION}

echo "Deployment completed successfully!"
echo "Configuration summary:"
echo "   Instance ID: ${INSTANCE_ID}"
echo "   Region: ${REGION}"
echo "   Start time (UTC): ${START_HOUR_UTC}:${START_MIN_UTC}"
echo "   Stop time (UTC): ${STOP_HOUR_UTC}:${STOP_MIN_UTC}"
echo "   Start schedule: ${START_CRON}"
echo "   Stop schedule: ${STOP_CRON}"
echo ""
echo "EC2 instance will automatically start at ${START_TIME} and stop at ${STOP_TIME} (local CEST time) daily."
