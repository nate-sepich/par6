import boto3
import os
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import uuid
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError
from models import User, Score, Status, ScoreType, calculate_golf_score, Tournament, TournamentSummary, TournamentStanding, TournamentStatus, TournamentFinalResults, normalize_score_type

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
        self.tournaments_table_name = os.environ.get('TOURNAMENTS_TABLE')
        
        if not all([self.users_table_name, self.sessions_table_name, self.scores_table_name, self.tournaments_table_name]):
            raise ValueError("Missing table environment variables")
        
        # Initialize table references
        self.users_table = self.dynamodb.Table(self.users_table_name)
        self.sessions_table = self.dynamodb.Table(self.sessions_table_name)
        self.scores_table = self.dynamodb.Table(self.scores_table_name)
        self.tournaments_table = self.dynamodb.Table(self.tournaments_table_name)
    
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
                     guesses_used: Optional[int], source_text: Optional[str],
                     score_type: ScoreType = ScoreType.REGULAR) -> Score:
        """Create or update a score for a user/date combination"""
        
        # Validate input
        if status == Status.SOLVED and (guesses_used is None or guesses_used < 1 or guesses_used > 6):
            raise ValueError("Solved status requires guesses_used between 1-6")
        if status == Status.DNF and guesses_used is not None:
            raise ValueError("DNF status forbids guesses_used")
        
        golf_score = calculate_golf_score(status, guesses_used, is_penalty=(score_type == ScoreType.PENALTY))
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
                score_type=score_type,
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
                'score_type': score_type.value,
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
                        score_type=normalize_score_type(item.get('score_type', 'regular')),
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
    
    # Tournament methods - Full DynamoDB implementation
    def create_tournament(self, name: str, start_date: str, duration_days: int, created_by: str, tournament_type: str = "private") -> Tournament:
        """Create a new tournament"""
        from datetime import datetime, timedelta
        tournament_id = self._generate_id()
        
        # Calculate end date based on duration (9 or 18 days)
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end_date = (start + timedelta(days=duration_days - 1)).strftime("%Y-%m-%d")
        now = datetime.utcnow()
        
        tournament = Tournament(
            tournament_id=tournament_id,
            name=name,
            start_date=start_date,
            end_date=end_date,
            duration_days=duration_days,
            created_by=created_by,
            participants=[created_by],
            created_at=now,
            is_active=True,
            status=TournamentStatus.ACTIVE,
            tournament_type=tournament_type
        )
        
        try:
            # Store tournament record with participants list
            self.tournaments_table.put_item(Item={
                'tournament_id': tournament_id,
                'name': name,
                'start_date': start_date,
                'end_date': end_date,
                'duration_days': duration_days,
                'created_by': created_by,
                'participants': [created_by],
                'created_at': now.isoformat(),
                'is_active': True,
                'status': TournamentStatus.ACTIVE.value,
                'tournament_type': tournament_type
            })
            
            # Also create participant record for easier querying
            self.tournaments_table.put_item(Item={
                'tournament_id': f"{tournament_id}#participant#{created_by}",
                'participant_id': created_by,
                'joined_at': now.isoformat()
            })
            
            print(f"[TELEMETRY] tournament_created: {name} by {created_by}")
            return tournament
            
        except ClientError as e:
            raise ValueError(f"Error creating tournament: {e}")
    
    def get_tournaments(self, user_id: str) -> List[TournamentSummary]:
        """Get tournaments the user is participating in"""
        try:
            summaries = []
            
            # Query for tournaments where user is a participant
            response = self.tournaments_table.query(
                IndexName='ParticipantIndex',
                KeyConditionExpression=Key('participant_id').eq(user_id)
            )
            
            # Get tournament details for each participation record
            for item in response.get('Items', []):
                # Extract tournament ID from participant record (format: {tournament_id}#participant#{user_id})
                full_tournament_id = item['tournament_id']
                if '#participant#' in full_tournament_id:
                    tournament_id = full_tournament_id.split('#participant#')[0]
                else:
                    # Handle legacy format for backwards compatibility
                    tournament_id = full_tournament_id.replace('#participant', '')
                
                # Get the main tournament record
                tournament_response = self.tournaments_table.get_item(
                    Key={'tournament_id': tournament_id}
                )
                
                if 'Item' in tournament_response:
                    tournament_item = tournament_response['Item']
                    
                    # Skip soft-deleted tournaments (is_active = False)
                    if not tournament_item.get('is_active', True):
                        print(f"[DEBUG] Skipping inactive tournament: {tournament_id}")
                        continue
                    
                    tournament = Tournament(
                        tournament_id=tournament_item['tournament_id'],
                        name=tournament_item['name'],
                        start_date=tournament_item['start_date'],
                        end_date=tournament_item['end_date'],
                        duration_days=tournament_item.get('duration_days', 18),  # Default to 18 for existing tournaments
                        created_by=tournament_item['created_by'],
                        participants=tournament_item['participants'],
                        created_at=datetime.fromisoformat(tournament_item['created_at']),
                        is_active=tournament_item['is_active'],
                        status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                        tournament_type=tournament_item.get('tournament_type', 'private'),  # Default to private for backward compatibility
                        ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                        winner_user_id=tournament_item.get('winner_user_id')
                    )
                    
                    standings = self._calculate_tournament_standings(tournament_id, user_id)
                    
                    summary = TournamentSummary(
                        tournament_id=tournament_id,
                        tournament=tournament,
                        standings=standings,
                        user_participating=True
                    )
                    summaries.append(summary)
            
            return summaries
            
        except ClientError as e:
            print(f"[ERROR] get_tournaments: {e}")
            return []
    
    def _find_tournament_by_short_id(self, short_id: str) -> Optional[str]:
        """Find tournament by 8-character prefix"""
        try:
            search_prefix = short_id.lower()
            print(f"[DEBUG] Searching for tournament with prefix: '{search_prefix}' (original: '{short_id}')")
            
            # Scan for tournaments that start with the short_id
            response = self.tournaments_table.scan(
                FilterExpression=Attr('tournament_id').begins_with(search_prefix) & 
                                ~Attr('tournament_id').contains('#participant#'),
                Limit=5  # Limit to avoid too many results
            )
            
            items = response.get('Items', [])
            print(f"[DEBUG] Found {len(items)} tournaments matching prefix '{search_prefix}'")
            
            if len(items) == 1:
                found_id = items[0]['tournament_id']
                print(f"[DEBUG] Found exact match: {found_id}")
                return found_id
            elif len(items) > 1:
                tournament_ids = [item['tournament_id'] for item in items]
                print(f"[DEBUG] Multiple tournaments found: {tournament_ids}")
                raise ValueError(f"Multiple tournaments found with code '{short_id.upper()}'. Please use the full tournament ID.")
            else:
                print(f"[DEBUG] No tournaments found with prefix '{search_prefix}'")
                return None
                
        except ClientError as e:
            print(f"[ERROR] _find_tournament_by_short_id: {e}")
            return None

    def join_tournament(self, tournament_id: str, user_id: str) -> Tournament:
        """Join a tournament by full ID or 8-character code"""
        try:
            print(f"[DEBUG] join_tournament called with tournament_id='{tournament_id}', user_id='{user_id}'")
            
            # If tournament_id is 8 characters or less, try to find by prefix
            if len(tournament_id) <= 8:
                print(f"[DEBUG] Short ID detected, searching for full tournament ID")
                full_id = self._find_tournament_by_short_id(tournament_id)
                if not full_id:
                    print(f"[ERROR] No tournament found with join code '{tournament_id.upper()}'")
                    raise ValueError(f"No tournament found with join code '{tournament_id.upper()}'")
                print(f"[DEBUG] Resolved short ID '{tournament_id}' to full ID '{full_id}'")
                tournament_id = full_id
            
            # Get tournament record
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            participants = tournament_item.get('participants', [])
            
            # Add user to participants if not already there
            if user_id not in participants:
                participants.append(user_id)
                
                # Update tournament record
                self.tournaments_table.update_item(
                    Key={'tournament_id': tournament_id},
                    UpdateExpression='SET participants = :participants',
                    ExpressionAttributeValues={':participants': participants}
                )
                
                # Create participant record
                self.tournaments_table.put_item(Item={
                    'tournament_id': f"{tournament_id}#participant#{user_id}",
                    'participant_id': user_id,
                    'joined_at': datetime.utcnow().isoformat()
                })
                
                print(f"[TELEMETRY] tournament_joined: {tournament_id} by {user_id}")
            
            # Return updated tournament
            return Tournament(
                tournament_id=tournament_item['tournament_id'],
                name=tournament_item['name'],
                start_date=tournament_item['start_date'],
                end_date=tournament_item['end_date'],
                duration_days=tournament_item.get('duration_days', 18),  # Default to 18 for backwards compatibility
                created_by=tournament_item['created_by'],
                participants=participants,
                created_at=datetime.fromisoformat(tournament_item['created_at']),
                is_active=tournament_item['is_active'],
                status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                tournament_type=tournament_item.get('tournament_type', 'private'),  # Default to private for backward compatibility
                ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                winner_user_id=tournament_item.get('winner_user_id')
            )
            
        except ClientError as e:
            raise ValueError(f"Error joining tournament: {e}")
    
    def leave_tournament(self, tournament_id: str, user_id: str) -> Tournament:
        """Leave a tournament"""
        try:
            # Get tournament record
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            participants = tournament_item.get('participants', [])
            
            # Check if user is actually a participant
            if user_id not in participants:
                raise ValueError("User is not a participant in this tournament")
            
            # Remove user from participants
            participants.remove(user_id)
            
            # Update tournament record
            self.tournaments_table.update_item(
                Key={'tournament_id': tournament_id},
                UpdateExpression='SET participants = :participants',
                ExpressionAttributeValues={':participants': participants}
            )
            
            # Remove participant record
            try:
                self.tournaments_table.delete_item(
                    Key={'tournament_id': f"{tournament_id}#participant#{user_id}"}
                )
            except ClientError as e:
                # Log warning but don't fail the operation if participant record doesn't exist
                print(f"[WARNING] Could not delete participant record: {e}")
            
            print(f"[TELEMETRY] tournament_left: {tournament_id} by {user_id}")
            
            # Return updated tournament
            return Tournament(
                tournament_id=tournament_item['tournament_id'],
                name=tournament_item['name'],
                start_date=tournament_item['start_date'],
                end_date=tournament_item['end_date'],
                duration_days=tournament_item.get('duration_days', 18),
                created_by=tournament_item['created_by'],
                participants=participants,
                created_at=datetime.fromisoformat(tournament_item['created_at']),
                is_active=tournament_item['is_active'],
                status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                tournament_type=tournament_item.get('tournament_type', 'private'),
                ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                winner_user_id=tournament_item.get('winner_user_id')
            )
            
        except ClientError as e:
            raise ValueError(f"Error leaving tournament: {e}")
    
    def get_tournament_details(self, tournament_id: str, user_id: str) -> TournamentSummary:
        """Get tournament details and standings"""
        try:
            # Get tournament record
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            
            tournament = Tournament(
                tournament_id=tournament_item['tournament_id'],
                name=tournament_item['name'],
                start_date=tournament_item['start_date'],
                end_date=tournament_item['end_date'],
                duration_days=tournament_item.get('duration_days', 18),  # Default to 18 for backwards compatibility
                created_by=tournament_item['created_by'],
                participants=tournament_item['participants'],
                created_at=datetime.fromisoformat(tournament_item['created_at']),
                is_active=tournament_item['is_active'],
                status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                tournament_type=tournament_item.get('tournament_type', 'private'),  # Default to private for backward compatibility
                ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                winner_user_id=tournament_item.get('winner_user_id')
            )
            
            standings = self._calculate_tournament_standings(tournament_id, user_id)
            user_participating = user_id in tournament_item.get('participants', [])
            
            return TournamentSummary(
                tournament_id=tournament_id,
                tournament=tournament,
                standings=standings,
                user_participating=user_participating
            )
            
        except ClientError as e:
            raise ValueError(f"Error getting tournament details: {e}")
    
    def _calculate_tournament_standings(self, tournament_id: str, current_user_id: str) -> List[TournamentStanding]:
        """Calculate current tournament standings"""
        try:
            # Get tournament details
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                return []
            
            tournament_item = tournament_response['Item']
            participants = tournament_item.get('participants', [])
            start_date = tournament_item['start_date']
            end_date = tournament_item['end_date']
            
            user_stats = {}
            
            # Calculate stats for each participant
            for user_id in participants:
                # Get user details
                user_response = self.users_table.get_item(Key={'user_id': user_id})
                if 'Item' not in user_response:
                    continue
                
                user_item = user_response['Item']
                total_score = 0
                completed_days = 0
                
                # Get scores for the tournament date range
                scores_response = self.scores_table.query(
                    IndexName='UserDateIndex',
                    KeyConditionExpression=Key('user_id').eq(user_id) & Key('puzzle_date').between(start_date, end_date)
                )
                
                for score_item in scores_response.get('Items', []):
                    total_score += score_item['golf_score']
                    completed_days += 1
                
                user_stats[user_id] = {
                    "handle": user_item['handle'],
                    "total_score": total_score,
                    "completed_days": completed_days
                }
            
            # Sort by total score (lower is better), then by completed days (higher is better)
            sorted_users = sorted(user_stats.items(), key=lambda x: (x[1]["total_score"], -x[1]["completed_days"]))
            
            standings = []
            for position, (user_id, stats) in enumerate(sorted_users, 1):
                standing = TournamentStanding(
                    user_id=user_id,
                    handle=stats["handle"],
                    total_score=stats["total_score"],
                    completed_days=stats["completed_days"],
                    position=position,
                    is_current_user=(user_id == current_user_id)
                )
                standings.append(standing)
            
            return standings
            
        except ClientError as e:
            print(f"[ERROR] _calculate_tournament_standings: {e}")
            return []
    
    def end_tournament(self, tournament_id: str, user_id: str) -> TournamentFinalResults:
        """End a tournament and return final results"""
        try:
            # Get tournament details
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            
            # Verify user is the creator
            if tournament_item['created_by'] != user_id:
                raise ValueError("Only the tournament creator can end the tournament")
            
            # Check if already ended
            if not tournament_item.get('is_active', True):
                raise ValueError("Tournament is already ended")
            
            now = datetime.utcnow()
            
            # Calculate final standings
            standings = self._calculate_tournament_standings(tournament_id, user_id)
            winner = standings[0] if standings else None
            
            # Update tournament to ended status
            update_expression = "SET #status = :status, is_active = :is_active, ended_at = :ended_at"
            expression_values = {
                ':status': TournamentStatus.ENDED.value,
                ':is_active': False,
                ':ended_at': now.isoformat()
            }
            
            if winner:
                update_expression += ", winner_user_id = :winner_user_id"
                expression_values[':winner_user_id'] = winner.user_id
            
            self.tournaments_table.update_item(
                Key={'tournament_id': tournament_id},
                UpdateExpression=update_expression,
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues=expression_values
            )
            
            # Create updated tournament object
            tournament = Tournament(
                tournament_id=tournament_item['tournament_id'],
                name=tournament_item['name'],
                start_date=tournament_item['start_date'],
                end_date=tournament_item['end_date'],
                duration_days=tournament_item.get('duration_days', 18),
                created_by=tournament_item['created_by'],
                participants=tournament_item['participants'],
                created_at=datetime.fromisoformat(tournament_item['created_at']),
                is_active=False,
                status=TournamentStatus.ENDED,
                tournament_type=tournament_item.get('tournament_type', 'private'),
                ended_at=now,
                winner_user_id=winner.user_id if winner else None
            )
            
            # Return final results
            return TournamentFinalResults(
                tournament_id=tournament_id,
                tournament=tournament,
                winner=winner,
                final_standings=standings,
                ended_at=now,
                total_participants=len(tournament_item['participants']),
                completed_days=tournament_item.get('duration_days', 18)
            )
            
        except ClientError as e:
            raise ValueError(f"Error ending tournament: {e}")
    
    def get_tournament_final_results(self, tournament_id: str) -> TournamentFinalResults:
        """Get final results for an ended tournament"""
        try:
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            
            # Check if tournament is ended
            if tournament_item.get('is_active', True):
                raise ValueError("Tournament is still active")
            
            # Calculate standings
            standings = self._calculate_tournament_standings(tournament_id, tournament_item['created_by'])
            winner = standings[0] if standings else None
            
            tournament = Tournament(
                tournament_id=tournament_item['tournament_id'],
                name=tournament_item['name'],
                start_date=tournament_item['start_date'],
                end_date=tournament_item['end_date'],
                duration_days=tournament_item.get('duration_days', 18),
                created_by=tournament_item['created_by'],
                participants=tournament_item['participants'],
                created_at=datetime.fromisoformat(tournament_item['created_at']),
                is_active=tournament_item['is_active'],
                status=TournamentStatus(tournament_item.get('status', 'ended')),
                tournament_type=tournament_item.get('tournament_type', 'private'),
                ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                winner_user_id=tournament_item.get('winner_user_id')
            )
            
            return TournamentFinalResults(
                tournament_id=tournament_id,
                tournament=tournament,
                winner=winner,
                final_standings=standings,
                ended_at=tournament.ended_at or datetime.utcnow(),
                total_participants=len(tournament_item['participants']),
                completed_days=tournament_item.get('duration_days', 18)
            )
            
        except ClientError as e:
            raise ValueError(f"Error getting tournament final results: {e}")
    
    def auto_end_expired_tournaments(self) -> List[str]:
        """Auto-end tournaments that have passed their end date"""
        try:
            ended_tournament_ids = []
            today = datetime.utcnow().strftime("%Y-%m-%d")
            
            # Scan for active tournaments that have expired
            response = self.tournaments_table.scan(
                FilterExpression=Attr('is_active').eq(True) & Attr('end_date').lt(today)
            )
            
            for tournament_item in response.get('Items', []):
                tournament_id = tournament_item['tournament_id']
                # Skip participant records
                if '#participant#' in tournament_id:
                    continue
                
                try:
                    # End the tournament
                    self.end_tournament(tournament_id, tournament_item['created_by'])
                    ended_tournament_ids.append(tournament_id)
                    print(f"[INFO] Auto-ended tournament: {tournament_id}")
                except Exception as e:
                    print(f"[ERROR] Failed to auto-end tournament {tournament_id}: {e}")
            
            return ended_tournament_ids
            
        except ClientError as e:
            print(f"[ERROR] auto_end_expired_tournaments: {e}")
            return []
    
    def get_public_tournaments(self, limit: int = 20, offset: int = 0) -> List[TournamentSummary]:
        """Get public tournaments for discovery"""
        try:
            # Scan for public tournaments (could be optimized with GSI later)
            response = self.tournaments_table.scan(
                FilterExpression=Attr('tournament_type').eq('public') & ~Attr('tournament_id').contains('#participant#'),
                Limit=limit
            )
            
            public_tournaments = []
            for tournament_item in response.get('Items', []):
                try:
                    tournament = Tournament(
                        tournament_id=tournament_item['tournament_id'],
                        name=tournament_item['name'],
                        start_date=tournament_item['start_date'],
                        end_date=tournament_item['end_date'],
                        duration_days=tournament_item.get('duration_days', 18),
                        created_by=tournament_item['created_by'],
                        participants=tournament_item['participants'],
                        created_at=datetime.fromisoformat(tournament_item['created_at']),
                        is_active=tournament_item['is_active'],
                        status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                        tournament_type=tournament_item.get('tournament_type', 'private'),
                        ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                        winner_user_id=tournament_item.get('winner_user_id')
                    )
                    
                    # Calculate standings (no user_id needed for public view)
                    standings = self._calculate_tournament_standings(tournament_item['tournament_id'], tournament_item['created_by'])
                    
                    summary = TournamentSummary(
                        tournament_id=tournament_item['tournament_id'],
                        tournament=tournament,
                        standings=standings,
                        user_participating=False  # Not relevant for public discovery
                    )
                    public_tournaments.append(summary)
                    
                except Exception as e:
                    print(f"[ERROR] Error processing public tournament {tournament_item.get('tournament_id')}: {e}")
                    continue
            
            return public_tournaments
            
        except ClientError as e:
            print(f"[ERROR] get_public_tournaments: {e}")
            return []
    
    def search_public_tournaments(self, query: str, limit: int = 20) -> List[TournamentSummary]:
        """Search public tournaments by name"""
        try:
            # Use scan with filter for name search (could be optimized with text search later)
            response = self.tournaments_table.scan(
                FilterExpression=Attr('tournament_type').eq('public') & 
                                ~Attr('tournament_id').contains('#participant#') & 
                                Attr('name').contains(query),
                Limit=limit
            )
            
            search_results = []
            for tournament_item in response.get('Items', []):
                try:
                    tournament = Tournament(
                        tournament_id=tournament_item['tournament_id'],
                        name=tournament_item['name'],
                        start_date=tournament_item['start_date'],
                        end_date=tournament_item['end_date'],
                        duration_days=tournament_item.get('duration_days', 18),
                        created_by=tournament_item['created_by'],
                        participants=tournament_item['participants'],
                        created_at=datetime.fromisoformat(tournament_item['created_at']),
                        is_active=tournament_item['is_active'],
                        status=TournamentStatus(tournament_item.get('status', 'active' if tournament_item['is_active'] else 'ended')),
                        tournament_type=tournament_item.get('tournament_type', 'private'),
                        ended_at=datetime.fromisoformat(tournament_item['ended_at']) if tournament_item.get('ended_at') else None,
                        winner_user_id=tournament_item.get('winner_user_id')
                    )
                    
                    # Calculate standings (no user_id needed for public view)
                    standings = self._calculate_tournament_standings(tournament_item['tournament_id'], tournament_item['created_by'])
                    
                    summary = TournamentSummary(
                        tournament_id=tournament_item['tournament_id'],
                        tournament=tournament,
                        standings=standings,
                        user_participating=False  # Not relevant for public search
                    )
                    search_results.append(summary)
                    
                except Exception as e:
                    print(f"[ERROR] Error processing search result {tournament_item.get('tournament_id')}: {e}")
                    continue
            
            return search_results
            
        except ClientError as e:
            print(f"[ERROR] search_public_tournaments: {e}")
            return []
    
    def delete_tournament(self, tournament_id: str, user_id: str) -> None:
        """Soft delete a tournament (creator only) - marks as inactive"""
        try:
            # Get tournament record to verify ownership
            tournament_response = self.tournaments_table.get_item(
                Key={'tournament_id': tournament_id}
            )
            
            if 'Item' not in tournament_response:
                raise ValueError("Tournament not found")
            
            tournament_item = tournament_response['Item']
            
            # Verify user is the creator
            if tournament_item['created_by'] != user_id:
                raise PermissionError("Only the tournament creator can delete the tournament")
            
            print(f"[DEBUG] Soft deleting tournament {tournament_id}")
            
            # Soft delete by setting is_active to False and adding deleted timestamp
            now = datetime.utcnow()
            self.tournaments_table.update_item(
                Key={'tournament_id': tournament_id},
                UpdateExpression='SET is_active = :is_active, deleted_at = :deleted_at',
                ExpressionAttributeValues={
                    ':is_active': False,
                    ':deleted_at': now.isoformat()
                }
            )
            
            print(f"[TELEMETRY] tournament_soft_deleted: {tournament_id} by {user_id}")
            
        except ClientError as e:
            print(f"[ERROR] delete_tournament: {e}")
            raise ValueError(f"Error deleting tournament: {e}")
    
    # MARK: - Penalty Score Management
    
    def insert_penalty_score(self, user_id: str, puzzle_date: str) -> Score:
        """Insert a penalty score for a user who missed a day"""
        # Check if user already has a score for this date
        existing_response = self.scores_table.query(
            IndexName='UserDateIndex',
            KeyConditionExpression=Key('user_id').eq(user_id) & Key('puzzle_date').eq(puzzle_date)
        )
        
        if existing_response['Items']:
            # User already has a score for this date, don't override
            print(f"[INFO] User {user_id} already has score for {puzzle_date}, skipping penalty")
            return None
        
        # Insert penalty score
        score_id = self._generate_id()
        now = datetime.utcnow()
        golf_score = 8  # Quad bogey
        
        score = Score(
            score_id=score_id,
            user_id=user_id,
            puzzle_date=puzzle_date,
            status=Status.DNF,
            guesses_used=None,
            golf_score=golf_score,
            source_text="Busy Bunker - Missed Day",
            score_type=ScoreType.PENALTY,
            created_at=now,
            updated_at=now
        )
        
        self.scores_table.put_item(Item={
            'score_id': score_id,
            'user_id': user_id,
            'puzzle_date': puzzle_date,
            'status': Status.DNF.value,
            'guesses_used': None,
            'golf_score': golf_score,
            'source_text': "Busy Bunker - Missed Day",
            'score_type': ScoreType.PENALTY.value,
            'created_at': now.isoformat(),
            'updated_at': now.isoformat()
        })
        
        print(f"[TELEMETRY] penalty_score_inserted: {user_id} {puzzle_date}")
        return score
    
    def get_active_users(self, days_back: int = 7) -> List[str]:
        """Get list of user IDs who have been active in the last N days"""
        try:
            active_users = set()
            cutoff_date = (datetime.utcnow() - timedelta(days=days_back)).strftime('%Y-%m-%d')
            
            # Scan scores table for recent activity
            scan_kwargs = {
                'FilterExpression': Attr('puzzle_date').gte(cutoff_date)
            }
            response = self.scores_table.scan(**scan_kwargs)
            
            while True:
                for item in response.get('Items', []):
                    active_users.add(item['user_id'])
                if 'LastEvaluatedKey' not in response:
                    break
                response = self.scores_table.scan(ExclusiveStartKey=response['LastEvaluatedKey'], **scan_kwargs)
            
            return list(active_users)
            
        except ClientError as e:
            print(f"[ERROR] get_active_users: {e}")
            return []
    
    def apply_daily_penalties(self, puzzle_date: str) -> int:
        """Apply penalty scores for all active users who missed today"""
        try:
            # Get active users (those who played in last 7 days)
            active_users = self.get_active_users(days_back=7)
            penalties_applied = 0
            
            for user_id in active_users:
                # Check if user has score for today
                existing_response = self.scores_table.query(
                    IndexName='UserDateIndex',
                    KeyConditionExpression=Key('user_id').eq(user_id) & Key('puzzle_date').eq(puzzle_date)
                )
                
                if not existing_response['Items']:
                    # User missed today, apply penalty
                    self.insert_penalty_score(user_id, puzzle_date)
                    penalties_applied += 1
            
            print(f"[INFO] Applied {penalties_applied} penalty scores for {puzzle_date}")
            return penalties_applied
            
        except Exception as e:
            print(f"[ERROR] apply_daily_penalties: {e}")
            return 0

# Global storage instance
storage = ReadableDynamoDBStorage()
