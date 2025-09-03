from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime, date
import uuid
from enum import Enum

class Status(str, Enum):
    SOLVED = "solved"
    DNF = "dnf"

class ScoreType(str, Enum):
    REGULAR = "regular"  # User submitted score
    PENALTY = "penalty"  # Busy bunker auto-assigned


def normalize_score_type(value: Optional[str]) -> "ScoreType":
    """Normalize legacy or unknown score_type strings to a valid ScoreType.

    Accepted inputs (case-insensitive):
    - "regular" (or legacy "standard") -> ScoreType.REGULAR
    - "penalty" -> ScoreType.PENALTY
    Any other value or None defaults to ScoreType.REGULAR for backward compatibility.
    """
    if not value:
        return ScoreType.REGULAR
    v = str(value).strip().lower()
    if v == "penalty":
        return ScoreType.PENALTY
    if v in ("regular", "standard"):
        return ScoreType.REGULAR
    # Fallback to regular to avoid breaking older data
    return ScoreType.REGULAR


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
    score_type: Optional[ScoreType] = ScoreType.REGULAR
    created_at: datetime
    updated_at: datetime

class LeaderboardEntry(BaseModel):
    user_id: str
    handle: str
    total_golf_score: int
    rounds_played: int

# Tournament Models

class TournamentStatus(str, Enum):
    ACTIVE = "active"
    ENDED = "ended"
    ARCHIVED = "archived"

class TournamentCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=100)
    start_date: str  # YYYY-MM-DD format
    duration_days: int = Field(default=18, ge=9, le=18)  # 9 or 18 days
    tournament_type: str = Field(default="private")  # "public" or "private"

class Tournament(BaseModel):
    tournament_id: str
    name: str
    start_date: str
    end_date: str
    duration_days: int  # 9 or 18 days
    created_by: str
    participants: List[str]
    created_at: datetime
    is_active: bool
    status: TournamentStatus
    tournament_type: str = "private"  # "public" or "private"
    ended_at: Optional[datetime] = None
    winner_user_id: Optional[str] = None

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

class TournamentFinalResults(BaseModel):
    tournament_id: str
    tournament: Tournament
    winner: Optional[TournamentStanding]
    final_standings: List[TournamentStanding]
    ended_at: datetime
    total_participants: int
    completed_days: int


def calculate_golf_score(status: Status, guesses_used: Optional[int], is_penalty: bool = False) -> int:
    """Convert Wordle guesses to golf scores according to spec"""
    if is_penalty:
        return 8  # Quad bogey (+4) for busy bunker
    
    if status == Status.DNF:
        return 8  # Quad bogey (+4) for failing to guess correctly
    
    if guesses_used is None:
        raise ValueError("guesses_used required for solved status")
    
    golf_mapping = {
        1: -3,  # Ace
        2: -2,  # Eagle
        3: -1,  # Birdie
        4: 0,   # Par
        5: 1,   # Bogey
        6: 2,   # Double Bogey
    }
    
    if guesses_used not in golf_mapping:
        raise ValueError(f"Invalid guesses_used: {guesses_used}")
    
    return golf_mapping[guesses_used]