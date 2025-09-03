import json
import os
from datetime import datetime, timedelta
from readable_dynamodb_storage import storage

def lambda_handler(event, context):
    """
    Scheduled Lambda function to apply daily penalties for missed Wordles.
    Triggered by EventBridge (CloudWatch Events) daily at 11:59 PM UTC.
    """
    try:
        # Get today's date (or use date from event if provided for testing)
        if event.get('puzzle_date'):
            puzzle_date = event['puzzle_date']
        else:
            # Use UTC time, apply penalties for "today"
            puzzle_date = datetime.utcnow().strftime('%Y-%m-%d')
        
        print(f"[INFO] Starting penalty processing for {puzzle_date}")
        
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