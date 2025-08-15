#!/usr/bin/env python3
"""
Local development server for Par6 Golf API
Uses in-memory storage instead of DynamoDB
"""

import os
import uvicorn
from app import app

if __name__ == "__main__":
    # Ensure we don't use DynamoDB storage for local development
    os.environ.pop('AWS_LAMBDA_FUNCTION_NAME', None)
    os.environ.pop('DYNAMODB_TABLE', None)
    
    print("🏌️ Starting Par6 Golf API in local development mode...")
    print("📱 Using in-memory storage (data will be lost on restart)")
    print("🔗 API will be available at: http://localhost:8000")
    print("📊 API docs available at: http://localhost:8000/docs")
    
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        reload=True,
        log_level="info"
    )