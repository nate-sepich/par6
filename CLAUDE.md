# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Par6 Golf is a Wordle score tracking app with a FastAPI backend deployed on AWS Serverless and an iOS SwiftUI frontend. It converts Wordle guesses into golf scores (1 guess = Ace, 2 = Eagle, etc.) and provides tournaments and leaderboards.

**Current Status**: Backend is deployed and functional. Frontend connects to live API.

## Architecture

### Backend (AWS Serverless)
- **FastAPI** application running on **AWS Lambda** 
- **DynamoDB** with 4 tables: Users, Sessions, Scores, Tournaments
- **API Gateway** with CORS enabled
- **Infrastructure as Code** using AWS SAM (Serverless Application Model)
- **Deployed endpoint**: `https://9d4oqidsq0.execute-api.us-west-2.amazonaws.com/dev`

### Frontend (iOS SwiftUI)
- Native iOS app in Swift
- Session-based authentication with bearer tokens
- Real-time tournaments and leaderboards

## Common Development Commands

### Backend Development & Deployment

**IMPORTANT**: Always use the AWS SAM MCP tools for backend/API work, not direct AWS CLI calls.

```bash
# Local development (uses in-memory storage)
cd backend/src && python local_dev.py

# Quick deployment to environments
cd backend
./deploy.sh dev       # Deploy to development
./deploy.sh staging   # Deploy to staging  
./deploy.sh prod      # Deploy to production

# Manual deployment using SAM MCP tools (preferred)
# Use sam_build and sam_deploy MCP tools instead of direct SAM CLI
```

### Mobile Development

```bash
# Open project in Xcode
open mobile/Par6_Golf.xcodeproj
```

## Key Architecture Details

### DynamoDB Schema (Multi-table design)

1. **Users Table** (`par6-users-{env}`)
   - PK: `user_id`, GSI: `HandleIndex` on `handle_lower`

2. **Sessions Table** (`par6-sessions-{env}`)  
   - PK: `session_token`, TTL: 30 days

3. **Scores Table** (`par6-scores-{env}`)
   - PK: `score_id`, GSI1: `UserDateIndex`, GSI2: `DateIndex`

4. **Tournaments Table** (`par6-tournaments-{env}`)
   - PK: `tournament_id`, GSI1: `CreatedByIndex`, GSI2: `ParticipantIndex`

### Environment Configuration

The backend supports three environments via `samconfig.toml`:
- **dev**: Development (default, uses `par6-golf-backend` stack)
- **staging**: Pre-production (`par6-golf-backend-staging` stack)  
- **prod**: Production (`par6-golf-backend-prod` stack)

### Dependencies

- **Backend**: FastAPI 0.104.1, Pydantic, Boto3, Mangum (Lambda adapter)
- **Frontend**: SwiftUI, native iOS dependencies

## Development Workflow

1. **Backend changes**: Use SAM MCP tools for build/deploy, test locally with `local_dev.py`
2. **Frontend changes**: Build and test in Xcode simulator
3. **API integration**: Backend is already deployed, frontend uses live endpoint

## Important Notes

- Backend uses DynamoDB for persistence (not in-memory storage)
- CORS is configured for cross-origin requests
- Tournament visibility bug was recently fixed (participant indexing)
- Session-based authentication with 30-day TTL
- All infrastructure managed through SAM templates (`template.yaml`)