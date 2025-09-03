name: Bug report
description: Report a problem
title: "fix: <short description>"
labels: [bug]
body:
  - type: dropdown
    id: area
    attributes:
      label: Area
      options:
        - Backend (FastAPI/Lambda)
        - Mobile (iOS/SwiftUI)
    validations:
      required: true
  - type: input
    id: env
    attributes:
      label: Environment
      description: Backend env (dev/staging/prod) or iOS device/OS version
  - type: textarea
    id: repro
    attributes:
      label: Steps to Reproduce
      description: Numbered steps to reproduce the issue
      placeholder: |
        1. ...
        2. ...
        3. ...
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Logs / Screenshots
      description: Include relevant logs (e.g., CloudWatch for backend) or screenshots.
