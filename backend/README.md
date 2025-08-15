# Par6 Golf Backend

FastAPI backend deployed on AWS Lambda using SAM with DynamoDB persistence.

## Prerequisites

- AWS CLI installed and configured
- SAM CLI installed
- Python 3.11+
- Docker (for local testing)

## Local Development

```bash
# Install dependencies
pip install -r src/requirements.txt

# Run locally (uses in-memory storage)
cd src && python local_dev.py

# Test API
curl http://localhost:8000/api/leaderboard?start_date=2024-01-01&end_date=2024-12-31
```

## Deployment

### Quick Deploy (Development)
```bash
./deploy.sh dev
```

### Manual Deploy
```bash
# Build the application
sam build

# Deploy to dev environment
sam deploy --config-env default

# Deploy to production
sam deploy --config-env prod
```

## API Endpoints

- `POST /api/users` - Register user
- `POST /api/scores` - Submit score (authenticated)
- `GET /api/scores` - Get user scores (authenticated) 
- `GET /api/leaderboard` - Public leaderboard

## Architecture

- **AWS Lambda**: Serverless compute
- **API Gateway**: HTTP API with CORS
- **DynamoDB**: Persistent NoSQL storage with multiple human-readable tables
- **CloudFormation**: Infrastructure as Code

## DynamoDB Schema

**Human-Readable Multi-Table Design:**

### 1. Users Table (`par6-users-{env}`)
- **Primary Key**: `user_id` (string)
- **GSI**: `HandleIndex` on `handle_lower`
- **Fields**: `user_id`, `handle`, `handle_lower`, `created_at`

### 2. Sessions Table (`par6-sessions-{env}`)
- **Primary Key**: `session_token` (string)
- **TTL**: `expires_at` (30 days)
- **Fields**: `session_token`, `user_id`, `created_at`, `expires_at`

### 3. Scores Table (`par6-scores-{env}`)
- **Primary Key**: `score_id` (string)
- **GSI1**: `UserDateIndex` on `user_id` + `puzzle_date`
- **GSI2**: `DateIndex` on `puzzle_date` + `score_id`
- **Fields**: `score_id`, `user_id`, `puzzle_date`, `status`, `guesses_used`, `golf_score`, `source_text`, `created_at`, `updated_at`

## Environment Variables

- `ENVIRONMENT`: dev/staging/prod
- `USERS_TABLE`: Users table name (auto-set by SAM)
- `SESSIONS_TABLE`: Sessions table name (auto-set by SAM)
- `SCORES_TABLE`: Scores table name (auto-set by SAM)
- `AWS_REGION`: AWS deployment region