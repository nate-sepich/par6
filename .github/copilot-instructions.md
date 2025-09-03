# Par6 GitHub Copilot Guidance

This document guides GitHub Copilot Chat and contributors when working in this repository. It mirrors the intent of CLAUDE.md and codifies our core policies.

Project overview
- Par6 Golf tracks Wordle scores like golf, with tournaments and leaderboards.
- Backend: FastAPI on AWS Lambda via API Gateway and DynamoDB; IaC via AWS SAM.
- Mobile: iOS SwiftUI app connecting to live API.

Architecture at a glance
- Backend
  - FastAPI on Lambda (Mangum), API Gateway with CORS
  - DynamoDB tables: Users, Sessions, Scores, Tournaments
  - SAM template: backend/template.yaml
  - Deployed endpoint (dev): https://9d4oqidsq0.execute-api.us-west-2.amazonaws.com/dev
- Mobile
  - SwiftUI app in mobile/Par6_Golf

Development workflow
- Backend
  - Always use AWS SAM MCP tools for backend/API work. Avoid raw AWS CLI and SAM CLI.
  - Environments in backend/samconfig.toml
  - Local dev: backend/src/local_dev.py
  - Deploy: backend/deploy.sh dev|staging|prod or SAM MCP tools
- Mobile
  - Open Xcode project: mobile/Par6_Golf.xcodeproj

Policies & guardrails
- Use SAM MCP tools; do not suggest unstructured AWS CLI/SAM CLI commands.
- Backend is already deployed; manage infra via SAM templates only.
- Follow Spec-Driven Development (SDD): start features with scripts/create-new-feature.sh and work under specs/###-...
- Keep answers concise and actionable; reference concrete repo paths.

Quick references
- Backend: backend/template.yaml, backend/samconfig.toml, backend/src/, backend/tests/
- Mobile: mobile/Par6_Golf.xcodeproj, mobile/Par6_Golf/
- SDD: scripts/create-new-feature.sh, specs/

If guidance conflicts, defer to this file and the SDD process in .github/CONTRIBUTING.md.
