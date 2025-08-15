# Par6 Golf - Cloud Deployment Structure

## Recommended Folder Structure

```
Par_6/
├── backend/                    # FastAPI Lambda backend
│   ├── src/                   # Lambda function source
│   │   ├── app.py            # Lambda handler (main.py renamed)
│   │   ├── models.py         # Existing models
│   │   ├── storage.py        # Existing storage
│   │   └── requirements.txt  # Python dependencies
│   ├── template.yaml         # SAM template for infrastructure
│   └── samconfig.toml        # SAM configuration
├── mobile/                   # Swift iOS app
│   ├── Par6_Golf/            # Existing iOS app
│   └── Par6_Golf.xcodeproj/  # Xcode project
├── infrastructure/           # Additional IaC if needed
└── docs/                     # Deployment documentation
```

## Why This Structure Works

1. **Separation of Concerns**: Backend and mobile clearly separated
2. **SAM Compatibility**: Backend follows SAM expected structure
3. **Lambda Web Adapter**: FastAPI can run on Lambda without modification
4. **Scalability**: Easy to add more services (database, auth, etc.)