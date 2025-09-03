from fastapi import APIRouter, HTTPException, Header, Depends, Query
from typing import Optional, List
from models import ScoreCreate, Score, LeaderboardEntry
import os

# Use DynamoDB storage in Lambda, fallback to in-memory for local development
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    from readable_dynamodb_storage import storage
else:
    from storage import storage

router = APIRouter(prefix="/api", tags=["scores"])

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

@router.post("/scores", response_model=Score)
async def submit_score(score: ScoreCreate, current_user = Depends(get_current_user)):
    """Submit a score for a puzzle date"""
    try:
        # Check if there's an existing penalty score for this date
        existing_scores = storage.get_user_scores(
            current_user.user_id,
            score.puzzle_date,
            score.puzzle_date
        )
        
        # If there's a penalty score and we're past the deadline (e.g., next day),
        # prevent overwriting (optional: you may want to allow overwriting on same day)
        # For now, we'll always allow overwriting to let users fix missed days
        
        saved_score = storage.upsert_score(
            user_id=current_user.user_id,
            puzzle_date=score.puzzle_date,
            status=score.status,
            guesses_used=score.guesses_used,
            source_text=score.source_text
        )
        return saved_score
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/scores", response_model=List[Score])
async def get_user_scores(current_user = Depends(get_current_user), 
                         start_date: str = Query(...), 
                         end_date: str = Query(...)):
    """Get scores for current user within date range"""
    try:
        scores = storage.get_user_scores(current_user.user_id, start_date, end_date)
        return scores
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/leaderboard", response_model=List[LeaderboardEntry])
async def get_leaderboard(start_date: str = Query(...), 
                         end_date: str = Query(...),
                         limit: int = Query(50)):
    """Get leaderboard for date range"""
    try:
        leaderboard = storage.get_leaderboard(start_date, end_date, limit)
        return leaderboard
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/players/{user_id}/scores", response_model=List[Score])
async def get_player_scores(
    user_id: str,
    start_date: str = Query(...),
    end_date: str = Query(...),
    current_user = Depends(get_current_user)
):
    """Get scores for a specific player (only if in shared tournament)"""
    try:
        # Check if current user and target user share any tournaments
        all_tournaments = storage.get_tournaments(current_user.user_id)
        target_in_shared_tournament = False
        
        for tournament in all_tournaments:
            if user_id in tournament.tournament.participants:
                target_in_shared_tournament = True
                break
        
        # Allow viewing own scores or scores of players in shared tournaments
        if user_id == current_user.user_id or target_in_shared_tournament:
            scores = storage.get_user_scores(user_id, start_date, end_date)
            return scores
        else:
            raise HTTPException(status_code=403, detail="Cannot view scores for this player")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))