#!/bin/bash

# Par6 Golf Backend Deployment Script
# Usage: ./deploy.sh [dev|staging|prod]

set -e

ENVIRONMENT=${1:-dev}

echo "🏌️ Deploying Par6 Golf Backend to $ENVIRONMENT..."

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: ./deploy.sh [dev|staging|prod]"
    exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI is not installed"
    echo "Please install SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI is not configured"
    echo "Please configure AWS CLI: aws configure"
    exit 1
fi

echo "🔨 Building SAM application..."
sam build -u

echo "📦 Deploying to AWS..."
if [ "$ENVIRONMENT" = "dev" ]; then
    sam deploy --config-env default
elif [ "$ENVIRONMENT" = "staging" ]; then
    sam deploy --config-env staging
elif [ "$ENVIRONMENT" = "prod" ]; then
    sam deploy --config-env prod
fi

echo "✅ Deployment complete!"
echo ""

# Determine stack name per samconfig
STACK_NAME="par6-golf-backend"
if [ "$ENVIRONMENT" = "staging" ]; then
  STACK_NAME="par6-golf-backend-staging"
elif [ "$ENVIRONMENT" = "prod" ]; then
  STACK_NAME="par6-golf-backend-prod"
fi

echo "🔗 API Endpoint:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text

echo ""
echo "📱 Update your mobile app API base URL to use the endpoint above"