from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, List
from models import UserCreate, UserResponse, ScoreCreate, Score, LeaderboardEntry, TournamentCreate, Tournament, TournamentSummary
import os

# Use DynamoDB storage in Lambda, fallback to in-memory for local development
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    from readable_dynamodb_storage import storage
else:
    from storage import storage

app = FastAPI(title="ParSix MVP", version="0.1.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files if present
static_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "static"))
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


def get_current_user(session_token: str = Header(None, alias="Authorization")):
    """Extract user from session token in Authorization header"""
    if not session_token:
        raise HTTPException(status_code=401, detail="Authorization header required")
    
    if session_token.startswith("Bearer "):
        session_token = session_token[7:]
    
    user = storage.get_user_by_session(session_token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid session token")
    
    return user

@app.get("/")
async def read_root():
    index_path = os.path.join(static_dir, "index.html")
    if os.path.isfile(index_path):
        return FileResponse(index_path)
    return {"status": "ok"}

@app.post("/api/users", response_model=UserResponse)
async def create_user(user_create: UserCreate):
    """Register a new user"""
    try:
        user, session_token = storage.create_user(user_create.handle)
        return UserResponse(
            user_id=user.user_id,
            handle=user.handle,
            session_token=session_token
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/scores", response_model=Score)
async def submit_score(score_create: ScoreCreate, current_user = Depends(get_current_user)):
    """Submit a score for the current user"""
    try:
        score = storage.upsert_score(
            user_id=current_user.user_id,
            puzzle_date=score_create.puzzle_date,
            status=score_create.status,
            guesses_used=score_create.guesses_used,
            source_text=score_create.source_text
        )
        return score
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/scores", response_model=List[Score])
async def get_user_scores(
    start_date: str,
    end_date: str,
    current_user = Depends(get_current_user)
):
    """Get scores for the current user within date range"""
    scores = storage.get_user_scores(current_user.user_id, start_date, end_date)
    return scores

@app.get("/api/leaderboard", response_model=List[LeaderboardEntry])
async def get_leaderboard(
    start_date: str,
    end_date: str,
    limit: int = 50
):
    """Get leaderboard for date range"""
    leaderboard_data = storage.get_leaderboard(start_date, end_date, limit)
    return [LeaderboardEntry(**entry) for entry in leaderboard_data]

# Tournament endpoints
@app.post("/api/tournaments", response_model=Tournament)
async def create_tournament(tournament_create: TournamentCreate, current_user = Depends(get_current_user)):
    """Create a new tournament"""
    try:
        tournament = storage.create_tournament(
            name=tournament_create.name,
            start_date=tournament_create.start_date,
            created_by=current_user.user_id
        )
        return tournament
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/tournaments", response_model=List[TournamentSummary])
async def get_tournaments(current_user = Depends(get_current_user)):
    """Get tournaments for the current user"""
    tournaments = storage.get_tournaments(current_user.user_id)
    return tournaments

@app.post("/api/tournaments/{tournament_id}/join", response_model=Tournament)
async def join_tournament(tournament_id: str, current_user = Depends(get_current_user)):
    """Join a tournament"""
    try:
        tournament = storage.join_tournament(tournament_id, current_user.user_id)
        return tournament
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/tournaments/{tournament_id}", response_model=TournamentSummary)
async def get_tournament_details(tournament_id: str, current_user = Depends(get_current_user)):
    """Get tournament details and standings"""
    try:
        tournament_summary = storage.get_tournament_details(tournament_id, current_user.user_id)
        return tournament_summary
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

def lambda_handler(event, context):
    """Lambda handler for API Gateway events"""
    try:
        from mangum import Mangum
        handler = Mangum(app, lifespan="off")
        return handler(event, context)
    except ImportError:
        # Fallback for local development
        return {"statusCode": 500, "body": "Mangum not available for local development"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)