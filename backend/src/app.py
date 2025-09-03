from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os

# Import routers
from routers import users, scores, tournaments

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

# Include routers
app.include_router(users.router)
app.include_router(scores.router)
app.include_router(tournaments.router)

# Serve static files if present
static_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "static"))
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


@app.get("/")
async def read_root():
    index_path = os.path.join(static_dir, "index.html")
    if os.path.isfile(index_path):
        return FileResponse(index_path)
    return {"status": "ok"}

def lambda_handler(event, context):
    """Unified Lambda handler for both API Gateway events and scheduled events"""
    import json
    
    # Handle case where event might be a string (from SAM local)
    if isinstance(event, str):
        try:
            event = json.loads(event)
        except json.JSONDecodeError:
            event = {}
    
    # Check if this is a scheduled event (EventBridge/CloudWatch Events)
    if event.get('source') == 'aws.events' or 'ScheduledEvent' in str(event.get('detail-type', '')):
        # Handle scheduled penalty processing
        return penalty_handler(event, context)
    
    # Handle API Gateway requests
    try:
        from mangum import Mangum
        handler = Mangum(app, lifespan="off")
        return handler(event, context)
    except ImportError:
        # Fallback for local development
        return {"statusCode": 500, "body": "Mangum not available for local development"}

def penalty_handler(event, context):
    """Handle scheduled penalty processing"""
    import json
    from datetime import datetime
    
    try:
        # Get today's date (or use date from event if provided for testing)
        if event.get('puzzle_date'):
            puzzle_date = event['puzzle_date']
        else:
            # Use UTC time, apply penalties for "today"
            puzzle_date = datetime.utcnow().strftime('%Y-%m-%d')
        
        print(f"[INFO] Starting penalty processing for {puzzle_date}")
        
        # Import storage here to avoid circular imports
        if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
            from readable_dynamodb_storage import storage
        else:
            from storage import storage
        
        # Apply penalties for all active users who missed today
        penalties_applied = storage.apply_daily_penalties(puzzle_date)
        
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully applied {penalties_applied} penalties for {puzzle_date}',
                'puzzle_date': puzzle_date,
                'penalties_applied': penalties_applied
            })
        }
        
        print(f"[SUCCESS] Penalty processing complete: {penalties_applied} penalties applied")
        return response
        
    except Exception as e:
        print(f"[ERROR] Penalty processing failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Penalty processing failed: {str(e)}'
            })
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)