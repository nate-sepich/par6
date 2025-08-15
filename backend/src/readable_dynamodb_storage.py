import boto3
import os
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import uuid
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError
from models import User, Score, Status, calculate_golf_score

class ReadableDynamoDBStorage:
    """
    Human-readable DynamoDB storage with separate tables for different entities.
    Much easier to understand and debug than single-table design.
    """
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        
        # Get table names from environment variables
        self.users_table_name = os.environ.get('USERS_TABLE')
        self.sessions_table_name = os.environ.get('SESSIONS_TABLE')
        self.scores_table_name = os.environ.get('SCORES_TABLE')
        
        if not all([self.users_table_name, self.sessions_table_name, self.scores_table_name]):
            raise ValueError("Missing table environment variables")
        
        # Initialize table references
        self.users_table = self.dynamodb.Table(self.users_table_name)
        self.sessions_table = self.dynamodb.Table(self.sessions_table_name)
        self.scores_table = self.dynamodb.Table(self.scores_table_name)
    
    def _generate_id(self) -> str:
        """Generate a unique ID"""
        return str(uuid.uuid4())
    
    # MARK: - User Management
    
    def create_user(self, handle: str) -> tuple[User, str]:
        """Create a new user or login to existing user and return (user, session_token)"""
        handle_lower = handle.lower()
        
        # Check if handle already exists
        try:
            response = self.users_table.query(
                IndexName='HandleIndex',
                KeyConditionExpression=Key('handle_lower').eq(handle_lower)
            )
            
            if response['Items']:
                # User exists, create new session for existing user
                existing_user_item = response['Items'][0]
                user_id = existing_user_item['user_id']
                
                user = User(
                    user_id=user_id,
                    handle=existing_user_item['handle'],
                    created_at=datetime.fromisoformat(existing_user_item['created_at'])
                )
                
                # Create new session
                session_token = self._generate_id()
                now = datetime.utcnow()
                expires_at = now + timedelta(days=30)
                
                self.sessions_table.put_item(Item={
                    'session_token': session_token,
                    'user_id': user_id,
                    'created_at': now.isoformat(),
                    'expires_at': int(expires_at.timestamp())
                })
                
                print(f"[TELEMETRY] user_logged_in: {handle}")
                return user, session_token
                
        except ClientError as e:
            raise ValueError(f"Error checking handle: {e}")
        
        # User doesn't exist, create new user
        user_id = self._generate_id()
        session_token = self._generate_id()
        now = datetime.utcnow()
        expires_at = now + timedelta(days=30)
        
        user = User(
            user_id=user_id,
            handle=handle,
            created_at=now
        )
        
        try:
            # Create user record
            self.users_table.put_item(Item={
                'user_id': user_id,
                'handle': handle,
                'handle_lower': handle_lower,
                'created_at': now.isoformat(),
            })
            
            # Create session record
            self.sessions_table.put_item(Item={
                'session_token': session_token,
                'user_id': user_id,
                'created_at': now.isoformat(),
                'expires_at': int(expires_at.timestamp())  # TTL requires epoch timestamp
            })
            
            print(f"[TELEMETRY] user_created: {handle}")
            return user, session_token
            
        except ClientError as e:
            raise ValueError(f"Error creating user: {e}")
    
    def get_user_by_session(self, session_token: str) -> Optional[User]:
        """Get user by session token"""
        try:
            # Get session record
            session_response = self.sessions_table.get_item(
                Key={'session_token': session_token}
            )
            
            if 'Item' not in session_response:
                return None
            
            session_item = session_response['Item']
            user_id = session_item['user_id']
            
            # Get user record
            user_response = self.users_table.get_item(
                Key={'user_id': user_id}
            )
            
            if 'Item' not in user_response:
                return None
            
            user_item = user_response['Item']
            return User(
                user_id=user_item['user_id'],
                handle=user_item['handle'],
                created_at=datetime.fromisoformat(user_item['created_at'])
            )
            
        except ClientError as e:
            print(f"[ERROR] get_user_by_session: {e}")
            return None
    
    # MARK: - Score Management
    
    def upsert_score(self, user_id: str, puzzle_date: str, status: Status,
                     guesses_used: Optional[int], source_text: Optional[str]) -> Score:
        """Create or update a score for a user/date combination"""
        
        # Validate input
        if status == Status.SOLVED and (guesses_used is None or guesses_used < 1 or guesses_used > 6):
            raise ValueError("Solved status requires guesses_used between 1-6")
        if status == Status.DNF and guesses_used is not None:
            raise ValueError("DNF status forbids guesses_used")
        
        golf_score = calculate_golf_score(status, guesses_used)
        now = datetime.utcnow()
        
        try:
            # Check for existing score for this user/date combination
            existing_response = self.scores_table.query(
                IndexName='UserDateIndex',
                KeyConditionExpression=Key('user_id').eq(user_id) & Key('puzzle_date').eq(puzzle_date)
            )
            
            if existing_response['Items']:
                # Update existing score
                existing_item = existing_response['Items'][0]
                score_id = existing_item['score_id']
                created_at = datetime.fromisoformat(existing_item['created_at'])
                
                print(f"[INFO] Updating existing score: {score_id}")
            else:
                # Create new score
                score_id = self._generate_id()
                created_at = now
                
                print(f"[INFO] Creating new score: {score_id}")
            
            # Create the score object
            score = Score(
                score_id=score_id,
                user_id=user_id,
                puzzle_date=puzzle_date,
                status=status,
                guesses_used=guesses_used,
                golf_score=golf_score,
                source_text=source_text,
                created_at=created_at,
                updated_at=now
            )
            
            # Store score record
            self.scores_table.put_item(Item={
                'score_id': score_id,
                'user_id': user_id,
                'puzzle_date': puzzle_date,
                'status': status.value,
                'guesses_used': guesses_used,
                'golf_score': golf_score,
                'source_text': source_text,
                'created_at': created_at.isoformat(),
                'updated_at': now.isoformat()
            })
            
            print(f"[TELEMETRY] score_upserted: {user_id} {puzzle_date} {status}")
            return score
            
        except ClientError as e:
            raise ValueError(f"Error upserting score: {e}")
    
    def get_user_scores(self, user_id: str, start_date: str, end_date: str) -> List[Score]:
        """Get scores for a user within date range"""
        try:
            scores: List[Score] = []

            query_kwargs = {
                'IndexName': 'UserDateIndex',
                'KeyConditionExpression': Key('user_id').eq(user_id) & Key('puzzle_date').between(start_date, end_date)
            }
            response = self.scores_table.query(**query_kwargs)
            
            while True:
                for item in response.get('Items', []):
                    scores.append(Score(
                        score_id=item['score_id'],
                        user_id=item['user_id'],
                        puzzle_date=item['puzzle_date'],
                        status=Status(item['status']),
                        guesses_used=item.get('guesses_used'),
                        golf_score=item['golf_score'],
                        source_text=item.get('source_text'),
                        created_at=datetime.fromisoformat(item['created_at']),
                        updated_at=datetime.fromisoformat(item['updated_at'])
                    ))
                if 'LastEvaluatedKey' not in response:
                    break
                response = self.scores_table.query(ExclusiveStartKey=response['LastEvaluatedKey'], **query_kwargs)
            
            return sorted(scores, key=lambda s: s.puzzle_date)
            
        except ClientError as e:
            print(f"[ERROR] get_user_scores: {e}")
            return []
    
    def get_leaderboard(self, start_date: str, end_date: str, limit: int = 50) -> List[dict]:
        """Get leaderboard for date range"""
        try:
            user_stats = {}
            
            # Get all scores in date range
            # Note: This uses a Scan with a FilterExpression. For large datasets,
            # consider using a write-time aggregation or a different index strategy.
            scan_kwargs = {
                'FilterExpression': Attr('puzzle_date').between(start_date, end_date)
            }
            response = self.scores_table.scan(**scan_kwargs)
            
            # Handle pagination
            while True:
                for item in response.get('Items', []):
                    user_id = item['user_id']
                    if user_id not in user_stats:
                        user_stats[user_id] = {
                            'total_golf_score': 0,
                            'rounds_played': 0
                        }
                    user_stats[user_id]['total_golf_score'] += item['golf_score']
                    user_stats[user_id]['rounds_played'] += 1
                
                if 'LastEvaluatedKey' not in response:
                    break
                
                response = self.scores_table.scan(
                    ExclusiveStartKey=response['LastEvaluatedKey'],
                    **scan_kwargs
                )
            
            # Get user details for each user in leaderboard
            leaderboard = []
            for user_id, stats in user_stats.items():
                try:
                    user_response = self.users_table.get_item(
                        Key={'user_id': user_id}
                    )
                    
                    if 'Item' in user_response:
                        user_item = user_response['Item']
                        leaderboard.append({
                            'user_id': user_id,
                            'handle': user_item['handle'],
                            'total_golf_score': stats['total_golf_score'],
                            'rounds_played': stats['rounds_played']
                        })
                except ClientError as e:
                    print(f"[ERROR] Failed to get user {user_id}: {e}")
                    continue
            
            # Sort by total_golf_score (ascending = better), then by rounds_played (descending = more active)
            leaderboard.sort(key=lambda x: (x['total_golf_score'], -x['rounds_played']))
            
            print(f"[TELEMETRY] leaderboard_fetched: {len(leaderboard)} users")
            return leaderboard[:limit]
            
        except ClientError as e:
            print(f"[ERROR] get_leaderboard: {e}")
            return []

# Global storage instance
storage = ReadableDynamoDBStorage()