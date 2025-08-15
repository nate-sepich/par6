# Par6 Golf - Cloud Deployment Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured (`aws configure`)
3. **SAM CLI** installed ([Installation Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
4. **Docker** (for local testing)

## Project Structure

```
Par_6/
├── backend/                 # AWS Lambda backend
│   ├── src/                # FastAPI source code
│   │   ├── app.py         # Lambda handler
│   │   ├── models.py      # Data models
│   │   ├── storage.py     # In-memory storage
│   │   └── requirements.txt
│   ├── template.yaml      # SAM infrastructure template
│   ├── samconfig.toml     # SAM configuration
│   └── deploy.sh          # Deployment script
├── mobile/                 # iOS Swift app
└── DEPLOYMENT.md          # This file
```

## Deployment Steps

### 1. Quick Deployment (Recommended)

```bash
cd backend
./deploy.sh dev    # Deploy to development
./deploy.sh prod   # Deploy to production
```

### 2. Manual Deployment

```bash
cd backend

# Build the application
sam build

# Deploy with guided setup (first time)
sam deploy --guided

# Or deploy to specific environment
sam deploy --config-env prod
```

### 3. Local Testing

```bash
cd backend

# Build and test locally
sam build
sam local start-api

# Test in another terminal
curl http://localhost:3000/api/leaderboard?start_date=2024-01-01&end_date=2024-12-31
```

## iOS App Configuration

After deployment, update the iOS app's API endpoint:

1. Get the API Gateway URL from deployment output
2. Replace `your-api-id` in `APIService.swift` with your actual API Gateway ID
3. Rebuild and deploy iOS app

## Infrastructure Details

### AWS Resources Created

- **Lambda Function**: Runs FastAPI backend
- **API Gateway**: HTTP API with CORS enabled
- **IAM Role**: Lambda execution permissions with DynamoDB access
- **CloudFormation Stack**: Infrastructure as code
- **DynamoDB Tables**: 3 human-readable tables
  - `par6-users-{env}`: User profiles and handles
  - `par6-sessions-{env}`: Authentication sessions with TTL
  - `par6-scores-{env}`: Game scores with user and date indexes

### Environments

- **dev**: Development environment with relaxed settings
- **staging**: Pre-production testing environment  
- **prod**: Production with optimized settings and persistent storage

## Cost Considerations

- **Lambda**: Pay per invocation (very low cost for this app)
- **API Gateway**: Pay per request (~$3.50 per million)
- **DynamoDB**: Pay per request (production only)
- **CloudWatch**: Logs and monitoring (minimal cost)

Estimated monthly cost for moderate usage: **$5-10**

## Monitoring & Logs

```bash
# View Lambda logs
sam logs -n Par6Function --stack-name par6-golf-backend-dev

# View API Gateway access logs in CloudWatch console
```

## Troubleshooting

### Common Issues

1. **Deployment fails**: Check AWS credentials and permissions
2. **API returns 502**: Check Lambda function logs
3. **CORS errors**: Verify API Gateway CORS configuration
4. **Cold starts**: Consider provisioned concurrency for production

### Useful Commands

```bash
# Validate SAM template
sam validate

# Delete stack
sam delete --stack-name par6-golf-backend-dev

# Check deployment status
aws cloudformation describe-stacks --stack-name par6-golf-backend-dev
```

## Next Steps

1. **Database Migration**: Replace in-memory storage with DynamoDB
2. **Authentication**: Add Cognito User Pools
3. **CDN**: Add CloudFront for global distribution
4. **Monitoring**: Set up CloudWatch dashboards and alarms
5. **CI/CD**: Set up GitHub Actions for automated deployment