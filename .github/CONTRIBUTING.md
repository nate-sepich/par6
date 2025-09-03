# Contributing to Par6

Thanks for your interest in contributing! This guide explains how we work.

## Spec-Driven Development (SDD)

We start all features with a written spec and a dedicated feature branch:

1. From repo root, run:
   - scripts/create-new-feature.sh "<short description>"
2. This creates a branch like `###-short-description` and a spec at `specs/###-short-description/spec.md` copied from `templates/spec-template.md`.
3. Fill out the spec before coding, then add a plan (`plan.md`) and tasks (`tasks.md`) in the same folder as needed.

When opening a PR, link the spec file and ensure the acceptance criteria are addressed.

## Backend (FastAPI on AWS Lambda)

- Always use AWS SAM MCP tools for backend/API work.
- Do not use raw AWS CLI or SAM CLI directly in this repo’s workflow.
- Environments and stacks are defined in `backend/samconfig.toml`.
- Local development: `backend/src/local_dev.py`.
- Deployments:
  - Quick: `backend/deploy.sh dev|staging|prod`
  - Preferred: use SAM MCP tools for build/deploy.
- Infrastructure is defined in `backend/template.yaml`; do not modify live infra outside of SAM.

## Mobile (iOS SwiftUI)

- Open `mobile/Par6_Golf.xcodeproj` in Xcode.
- Keep UI stable and accessible; ensure the app builds and passes tests before PRs.

## Pull Requests

- Link the spec (specs/###-.../spec.md) and reference the feature branch.
- Confirm tests/docs updated as needed.
- Confirm backend work used SAM MCP tools.
- Keep PRs focused and small where possible.

## Issues

- Use the provided issue templates.
- Feature requests should include user stories and acceptance criteria; maintainers may convert them into a spec.

## Security and Secrets

- Do not commit secrets or credentials.
- Avoid suggesting unvetted network calls or exposing sensitive infrastructure details.

## Communication

- Keep discussions constructive; prefer actionable, concrete suggestions.