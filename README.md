# Par6 Golf

A Wordle score tracking app built with SwiftUI and FastAPI on AWS Serverless.

## Project Overview

Par6 Golf converts Wordle guesses into golf scores and provides leaderboards and tournament functionality.

### Scoring System
- 1 guess = Ace (-3)
- 2 guesses = Eagle (-2) 
- 3 guesses = Birdie (-1)
- 4 guesses = Par (0)
- 5 guesses = Bogey (+1)
- 6 guesses = Double Bogey (+2)
- DNF = +4 penalty

## Architecture

### Backend
- **Framework**: FastAPI on AWS Lambda
- **Database**: DynamoDB (4 tables: Users, Sessions, Scores, Tournaments)
- **Infrastructure**: AWS SAM (Serverless Application Model)
- **API Endpoint**: `https://9d4oqidsq0.execute-api.us-west-2.amazonaws.com/dev`

### Mobile App
- **Framework**: SwiftUI (iOS)
- **Features**: Score tracking, tournaments, leaderboards
- **Authentication**: Session-based with bearer tokens

## Current Status

### Backend (✅ Deployed)
- User authentication and session management
- Score submission and retrieval
- Tournament creation and management
- Leaderboard calculation
- **Recent Fix**: Tournament visibility bug resolved (participant records properly indexed)

### Mobile App (🚧 App Store Review)
- Core functionality complete
- Screenshots generated for App Store submission
- Game Center entitlement configured

### App Store Submission Requirements
- ✅ Screenshots (iPhone & iPad dimensions)
- ✅ Game Center entitlement (`com.apple.developer.game-center`)
- ❌ Copyright information (pending in App Store Connect)
- ❌ Privacy Policy URL (required)

## Project Structure

```
Par_6/
├── backend/                    # AWS Lambda backend
│   ├── src/
│   │   ├── app.py             # FastAPI application
│   │   ├── models.py          # Pydantic data models
│   │   ├── readable_dynamodb_storage.py  # DynamoDB operations
│   │   └── storage.py         # Local development storage
│   ├── template.yaml          # SAM infrastructure template
│   └── samconfig.toml         # SAM deployment configuration
├── mobile/                    # iOS SwiftUI app
│   ├── Par6_Golf/
│   │   ├── ContentView.swift  # Main app interface
│   │   ├── APIService.swift   # Backend API client
│   │   ├── APIModels.swift    # Data models
│   │   └── Par6_Golf.entitlements  # App entitlements
│   └── icon_assets/           # App icons and screenshots
└── README.md
```

## Development

### Backend Deployment
```bash
cd backend
sam build
sam deploy
```

### Mobile Development
Open `mobile/Par6_Golf.xcodeproj` in Xcode.

## Recent Updates
- **Tournament Bug Fix**: Fixed issue where tournament creators couldn't see tournaments after other users joined
- **App Store Prep**: Generated required screenshot dimensions and configured entitlements
- **Infrastructure**: Deployed to AWS with DynamoDB backend
