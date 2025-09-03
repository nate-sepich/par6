from fastapi import APIRouter, HTTPException, Header, Depends
from typing import Optional
from models import UserCreate, UserResponse
import os

# Use DynamoDB storage in Lambda, fallback to in-memory for local development
if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
    from readable_dynamodb_storage import storage
else:
    from storage import storage

router = APIRouter(prefix="/api", tags=["users"])

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

@router.post("/users", response_model=UserResponse)
async def create_user(user: UserCreate):
    """Create a new user or login to existing user"""
    try:
        # Create user returns (User, session_token)
        created_user, session_token = storage.create_user(user.handle)
        
        # Return both user info and session token
        return UserResponse(
            user_id=created_user.user_id,
            handle=created_user.handle,
            session_token=session_token
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))