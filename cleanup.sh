#!/bin/bash
set -e

# Configuration
read -p "Enter AWS Region [default: eu-central-1]: " REGION
REGION=${REGION:-eu-central-1}

echo "Removing EventBridge targets and rules..."
aws events remove-targets --rule StartEC2ViaLambdaRule --ids StartEC2Lambda --region $REGION 2>/dev/null || true
aws events delete-rule --name StartEC2ViaLambdaRule --region $REGION 2>/dev/null || true
aws events remove-targets --rule StopEC2ViaLambdaRule --ids StopEC2Lambda --region $REGION 2>/dev/null || true
aws events delete-rule --name StopEC2ViaLambdaRule --region $REGION 2>/dev/null || true

echo "Removing Lambda function permissions..."
aws lambda remove-permission --function-name StartEC2InstanceLambda --statement-id allow-eventbridge-start --region $REGION 2>/dev/null || true
aws lambda remove-permission --function-name StopEC2InstanceLambda --statement-id allow-eventbridge-stop --region $REGION 2>/dev/null || true

echo "Deleting Lambda functions..."
aws lambda delete-function --function-name StartEC2InstanceLambda --region $REGION 2>/dev/null || true
aws lambda delete-function --function-name StopEC2InstanceLambda --region $REGION 2>/dev/null || true

echo "Removing IAM role and policies..."
aws iam delete-role-policy --role-name LambdaEC2SchedulerRole --policy-name EC2ControlPolicy 2>/dev/null || true
aws iam detach-role-policy --role-name LambdaEC2SchedulerRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name LambdaEC2SchedulerRole 2>/dev/null || true

echo "Cleaning up temporary directories..."
rm -rf lambda_start lambda_stop 2>/dev/null || true

echo "Cleanup completed successfully!"
echo "All AWS resources have been removed from region: $REGION"
