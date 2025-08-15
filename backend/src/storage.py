from typing import Dict, List, Optional
from datetime import datetime, date
import uuid
from models import User, Score, Status, calculate_golf_score

class InMemoryStorage:
    def __init__(self):
        self.users: Dict[str, User] = {}  # user_id -> User
        self.scores: Dict[str, Score] = {}  # score_id -> Score
        self.sessions: Dict[str, str] = {}  # session_token -> user_id
        self.handle_to_user_id: Dict[str, str] = {}  # handle (lowercase) -> user_id
        self.user_date_scores: Dict[str, str] = {}  # f"{user_id}:{date}" -> score_id
    
    def create_user(self, handle: str) -> tuple[User, str]:
        """Create a new user or login to existing user and return (user, session_token)"""
        handle_lower = handle.lower()
        
        if handle_lower in self.handle_to_user_id:
            # User exists, create new session for existing user
            user_id = self.handle_to_user_id[handle_lower]
            user = self.users[user_id]
            session_token = str(uuid.uuid4())
            self.sessions[session_token] = user_id
            
            print(f"[TELEMETRY] user_logged_in: {handle}")
            return user, session_token
        
        # User doesn't exist, create new user
        user_id = str(uuid.uuid4())
        session_token = str(uuid.uuid4())
        
        user = User(
            user_id=user_id,
            handle=handle,
            created_at=datetime.utcnow()
        )
        
        self.users[user_id] = user
        self.sessions[session_token] = user_id
        self.handle_to_user_id[handle_lower] = user_id
        
        print(f"[TELEMETRY] user_created: {handle}")
        return user, session_token
    
    def get_user_by_session(self, session_token: str) -> Optional[User]:
        """Get user by session token"""
        user_id = self.sessions.get(session_token)
        if user_id:
            return self.users.get(user_id)
        return None
    
    def upsert_score(self, user_id: str, puzzle_date: str, status: Status, 
                     guesses_used: Optional[int], source_text: Optional[str]) -> Score:
        """Create or update a score for a user/date combination"""
        
        # Validate input
        if status == Status.SOLVED and (guesses_used is None or guesses_used < 1 or guesses_used > 6):
            raise ValueError("Solved status requires guesses_used between 1-6")
        if status == Status.DNF and guesses_used is not None:
            raise ValueError("DNF status forbids guesses_used")
        
        golf_score = calculate_golf_score(status, guesses_used)
        
        # Check for existing score
        key = f"{user_id}:{puzzle_date}"
        existing_score_id = self.user_date_scores.get(key)
        
        now = datetime.utcnow()
        
        if existing_score_id:
            # Update existing score
            score = Score(
                score_id=existing_score_id,
                user_id=user_id,
                puzzle_date=puzzle_date,
                status=status,
                guesses_used=guesses_used,
                golf_score=golf_score,
                source_text=source_text,
                created_at=self.scores[existing_score_id].created_at,
                updated_at=now
            )
            self.scores[existing_score_id] = score
        else:
            # Create new score
            score_id = str(uuid.uuid4())
            score = Score(
                score_id=score_id,
                user_id=user_id,
                puzzle_date=puzzle_date,
                status=status,
                guesses_used=guesses_used,
                golf_score=golf_score,
                source_text=source_text,
                created_at=now,
                updated_at=now
            )
            self.scores[score_id] = score
            self.user_date_scores[key] = score_id
        
        print(f"[TELEMETRY] score_upserted: {user_id} {puzzle_date} {status}")
        return score
    
    def get_user_scores(self, user_id: str, start_date: str, end_date: str) -> List[Score]:
        """Get scores for a user within date range"""
        scores = []
        for score in self.scores.values():
            if (score.user_id == user_id and 
                start_date <= score.puzzle_date <= end_date):
                scores.append(score)
        return sorted(scores, key=lambda s: s.puzzle_date)
    
    def get_leaderboard(self, start_date: str, end_date: str, limit: int = 50) -> List[dict]:
        """Get leaderboard for date range"""
        user_stats = {}
        
        for score in self.scores.values():
            if start_date <= score.puzzle_date <= end_date:
                user_id = score.user_id
                if user_id not in user_stats:
                    user_stats[user_id] = {
                        "total_golf_score": 0,
                        "rounds_played": 0
                    }
                user_stats[user_id]["total_golf_score"] += score.golf_score
                user_stats[user_id]["rounds_played"] += 1
        
        leaderboard = []
        for user_id, stats in user_stats.items():
            user = self.users.get(user_id)
            if user:
                leaderboard.append({
                    "user_id": user_id,
                    "handle": user.handle,
                    "total_golf_score": stats["total_golf_score"],
                    "rounds_played": stats["rounds_played"]
                })
        
        # Sort by total_golf_score asc, then rounds_played desc
        leaderboard.sort(key=lambda x: (x["total_golf_score"], -x["rounds_played"]))
        
        print(f"[TELEMETRY] leaderboard_fetched: {len(leaderboard)} users")
        return leaderboard[:limit]

# Global storage instance
storage = InMemoryStorage()