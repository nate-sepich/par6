from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime, date
import uuid
from enum import Enum

class Status(str, Enum):
    SOLVED = "solved"
    DNF = "dnf"

class UserCreate(BaseModel):
    handle: str = Field(..., min_length=3, max_length=24)

class User(BaseModel):
    user_id: str
    handle: str
    created_at: datetime

class UserResponse(BaseModel):
    user_id: str
    handle: str
    session_token: str

class ScoreCreate(BaseModel):
    user_id: str
    puzzle_date: str  # YYYY-MM-DD format
    status: Status
    guesses_used: Optional[int] = None
    source_text: Optional[str] = None

class Score(BaseModel):
    score_id: str
    user_id: str
    puzzle_date: str
    status: Status
    guesses_used: Optional[int]
    golf_score: int
    source_text: Optional[str]
    created_at: datetime
    updated_at: datetime

class LeaderboardEntry(BaseModel):
    user_id: str
    handle: str
    total_golf_score: int
    rounds_played: int

# Tournament Models

class TournamentCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=100)
    start_date: str  # YYYY-MM-DD format

class Tournament(BaseModel):
    tournament_id: str
    name: str
    start_date: str
    end_date: str
    created_by: str
    participants: List[str]
    created_at: datetime
    is_active: bool

class TournamentScore(BaseModel):
    tournament_score_id: str
    tournament_id: str
    user_id: str
    day: int  # 1-18
    score: int
    puzzle_date: str
    created_at: datetime

class TournamentStanding(BaseModel):
    user_id: str
    handle: str
    total_score: int
    completed_days: int
    position: int
    is_current_user: bool

class TournamentSummary(BaseModel):
    tournament_id: str
    tournament: Tournament
    standings: List[TournamentStanding]
    user_participating: bool

def calculate_golf_score(status: Status, guesses_used: Optional[int]) -> int:
    """Convert Wordle guesses to golf scores according to spec"""
    if status == Status.DNF:
        return 5  # OB/DNF
    
    if guesses_used is None:
        raise ValueError("guesses_used required for solved status")
    
    golf_mapping = {
        1: -3,  # Ace
        2: -2,  # Eagle
        3: -1,  # Birdie
        4: 0,   # Par
        5: 1,   # Bogey
        6: 4,   # Snowman
    }
    
    if guesses_used not in golf_mapping:
        raise ValueError(f"Invalid guesses_used: {guesses_used}")
    
    return golf_mapping[guesses_used]