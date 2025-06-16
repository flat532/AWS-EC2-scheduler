# AWS EC2 Scheduler

Automated EC2 instance start/stop scheduling using AWS Lambda and EventBridge for cost optimization.

## Overview

This solution provides serverless automation for EC2 instance lifecycle management, reducing costs by up to 70% through intelligent scheduling. Ideal for development environments, batch processing workloads, and any predictable usage patterns.

## Architecture

```
EventBridge Rules (Cron) → Lambda Functions → EC2 Start/Stop Operations
```

**Components:**
- EventBridge Rules: Schedule triggers with cron expressions
- Lambda Functions: Serverless execution of EC2 operations  
- IAM Role: Secure permissions for EC2 start/stop actions
- CloudWatch Logs: Execution monitoring and debugging

## Features

- Custom scheduling with timezone support (CEST to UTC conversion)
- One-command deployment and cleanup
- Multi-region support
- Production-ready IAM security model
- AWS Free Tier eligible services
- Comprehensive error handling

## Cost Impact

**Example scenario:**
- t3.medium running 12h/day instead of 24h/day
- Monthly savings: ~$15 (50% reduction)
- Lambda execution costs: ~$0.07/month
- Net savings: ~$14.93/month per instance

## Quick Start

### Prerequisites
- AWS CLI configured with EC2, Lambda, IAM, EventBridge permissions
- Target EC2 instance ID

### Deploy
```bash
git clone https://github.com/flat532/aws-ec2-scheduler.git
cd aws-ec2-scheduler
chmod +x scheduler_deploy.sh
./scheduler_deploy.sh
```

### Remove
```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Configuration

During deployment, specify:
- EC2 Instance ID (e.g., i-0abc1234def56789)
- AWS Region (default: eu-central-1)
- Start time in 24h format (automatically converted from CEST to UTC)
- Stop time in 24h format (automatically converted from CEST to UTC)

## Use Cases

- **Development environments** - Auto-stop instances during off-hours
- **Batch processing** - Schedule compute resources for specific windows
- **Training/demo environments** - Ensure availability during business hours
- **Cost optimization** - Reduce idle time for predictable workloads

## Security

- Least privilege IAM roles with EC2-only permissions
- CloudWatch logging for full audit trail
- No hardcoded credentials or secrets
- Resource-specific targeting capabilities

## Monitoring

Check execution status via CloudWatch Logs:
- `/aws/lambda/StartEC2InstanceLambda`
- `/aws/lambda/StopEC2InstanceLambda`

Manual testing:
```bash
aws lambda invoke --function-name StartEC2InstanceLambda response.json
aws events list-rules --region your-region
```

## Files

- `scheduler_deploy.sh` - Complete infrastructure deployment
- `cleanup.sh` - Resource cleanup and removal

## Requirements

AWS services: EC2, Lambda, EventBridge, IAM, CloudWatch  
All services included in AWS Free Tier limits for typical usage.

## License

MIT License
