from fastapi import APIRouter, HTTPException, Header, Depends, Query
from typing import Optional, List
from models import TournamentCreate, Tournament, TournamentSummary
import os

# Use DynamoDB storage in Lambda, fallback to in-memory for local development
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    from readable_dynamodb_storage import storage
else:
    from storage import storage

router = APIRouter(prefix="/api", tags=["tournaments"])

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

@router.post("/tournaments", response_model=Tournament)
async def create_tournament(tournament_create: TournamentCreate, current_user = Depends(get_current_user)):
    """Create a new tournament"""
    try:
        tournament = storage.create_tournament(
            name=tournament_create.name,
            start_date=tournament_create.start_date,
            duration_days=tournament_create.duration_days,
            created_by=current_user.user_id,
            tournament_type=tournament_create.tournament_type
        )
        return tournament
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/tournaments", response_model=List[TournamentSummary])
async def get_tournaments(current_user = Depends(get_current_user)):
    """Get tournaments for the current user"""
    tournaments = storage.get_tournaments(current_user.user_id)
    return tournaments

# Public tournament endpoints (must come before parameterized routes)
@router.get("/tournaments/public", response_model=List[TournamentSummary])
async def get_public_tournaments(limit: int = 20, offset: int = 0):
    """Get public tournaments"""
    try:
        public_tournaments = storage.get_public_tournaments(limit=limit, offset=offset)
        return public_tournaments
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tournaments/search", response_model=List[TournamentSummary]) 
async def search_tournaments(q: str, limit: int = 20):
    """Search public tournaments by name"""
    try:
        search_results = storage.search_public_tournaments(query=q, limit=limit)
        return search_results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tournaments/{tournament_id}/join", response_model=Tournament)
async def join_tournament(tournament_id: str, current_user = Depends(get_current_user)):
    """Join a tournament"""
    try:
        tournament = storage.join_tournament(tournament_id, current_user.user_id)
        return tournament
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/tournaments/{tournament_id}/leave", response_model=Tournament)
async def leave_tournament(tournament_id: str, current_user = Depends(get_current_user)):
    """Leave a tournament"""
    try:
        tournament = storage.leave_tournament(tournament_id, current_user.user_id)
        return tournament
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/tournaments/{tournament_id}", response_model=TournamentSummary)
async def get_tournament_details(tournament_id: str, current_user = Depends(get_current_user)):
    """Get tournament details and standings"""
    try:
        tournament_summary = storage.get_tournament_details(tournament_id, current_user.user_id)
        return tournament_summary
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.delete("/tournaments/{tournament_id}")
async def delete_tournament(tournament_id: str, current_user = Depends(get_current_user)):
    """Delete a tournament (creator only)"""
    try:
        storage.delete_tournament(tournament_id, current_user.user_id)
        return {"message": "Tournament deleted successfully"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))