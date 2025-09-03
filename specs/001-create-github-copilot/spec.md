# Feature Specification: GitHub Copilot guidance and GitHub templates

**Feature Branch**: `001-create-github-copilot`  
**Created**: 2025-09-03  
**Status**: Draft  
**Input**: User description: "Create GitHub Copilot guidance files analogous to CLAUDE.md and CLAUDE.local.md, define .github/copilot-instructions.md for Copilot Chat usage, and propose PR/Issue templates referencing Spec-Driven Development and MCP tooling policies"

## Execution Flow (main)
```
1. Parse user description from Input
   → If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   → Identify: actors, actions, data, constraints
3. For each unclear aspect:
   → Mark with [NEEDS CLARIFICATION: specific question]
4. Fill User Scenarios & Testing section
   → If no clear user flow: ERROR "Cannot determine user scenarios"
5. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
6. Identify Key Entities (if data involved)
7. Run Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Spec has uncertainties"
   → If implementation details found: ERROR "Remove tech details"
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT these guidance files enable: consistent AI assistant and contributor behavior
- ❌ Avoid implementation specifics of CI or automation beyond files to create
- 👥 Written for maintainers and contributors; keeps language clear and directive

### Section Requirements
- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation
When creating guidance, do:
1. Carry forward policies in `CLAUDE.md` and `CLAUDE.local.md` (use AWS SAM MCP tools for backend; backend already deployed; env details live in `samconfig.toml`; Xcode for mobile)
2. Explicitly declare expectations for Copilot Chat interactions and guardrails
3. Reference Spec-Driven Development (scripts in `scripts/`) as the source of truth for feature work

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a maintainer, I want GitHub-native guidance so that GitHub Copilot Chat and contributors consistently follow our repository policies (SDD workflow, AWS SAM MCP tools usage, and environment context) without relying on external tools.

### Acceptance Scenarios
1. Given a developer opens Copilot Chat in this repo, when they ask how to deploy the backend, then the assistant responds with "use AWS SAM MCP tools" and avoids direct AWS CLI/SAM CLI commands, reflecting `CLAUDE.md` guidance.
2. Given a contributor opens a new pull request, when they see the PR template, then it requires linking the feature spec (under `specs/###-.../spec.md`) and confirming SDD checklist items.
3. Given a user opens a new issue to request a feature, when the issue template loads, then it instructs them to use the Spec-Driven Development flow and/or provides a structured prompt for maintainers to convert into a spec.
4. Given a bug report is filed, when the template is used, then it captures environment info (iOS/SwiftUI app or backend env), reproduction steps, and expected vs actual behavior.

### Edge Cases
- External contributors without knowledge of SDD workflow need clear instructions in CONTRIBUTING and templates.
- Conflicting instructions between CLAUDE and Copilot guidance should be resolved by centralizing shared policies and pointing to one source of truth.
- Private/local-only rules: decide whether to keep a `.local` guidance file in-repo or in maintainers' private notes. [NEEDS CLARIFICATION: should local guidance live in-repo as `.github/COPILOT.local.md` or remain outside?]

## Requirements *(mandatory)*

### Functional Requirements
- FR-001: Provide a GitHub-native Copilot guidance file that mirrors the intent and content of `CLAUDE.md` for Copilot Chat usage (project overview, architecture, dev workflow, key policies).
- FR-002: Ensure guidance explicitly states: use AWS SAM MCP tools for backend/API work; avoid raw AWS CLI/SAM CLI; backend is deployed; refer to `backend/samconfig.toml` for envs; open iOS project with Xcode for mobile work.
- FR-003: Add a PR template that requires linking the feature spec file, feature branch name, and completing a short checklist (spec ready, plan prepared, tests/docs considered).
- FR-004: Add Issue templates:
   - Feature request template that nudges SDD (or provides a structured intake for maintainers to turn into a spec).
   - Bug report template capturing repro, scope (backend/mobile), environment details, and expected vs. actual.
- FR-005: Add/Update CONTRIBUTING.md to describe the SDD workflow (scripts in `scripts/`, branch naming, spec location, planning), and reiterate the MCP tooling policy.
- FR-006: Centralize guidance to remove duplication between `CLAUDE.md` and Copilot guidance by pointing both to a shared policy section and keeping content consistent.
- FR-007: Ensure all added files live under `.github/` where applicable, using conventional file paths.

Examples of likely artifacts to create/update (subject to resolution):
- `.github/copilot-instructions.md` (Copilot Chat repo guidance; mirrors `CLAUDE.md` content & tone)
- `.github/COPILOT.local.md` (optional local/private addendum) [NEEDS CLARIFICATION]
- `.github/PULL_REQUEST_TEMPLATE.md` (PR checklist referencing SDD and spec links)
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/CONTRIBUTING.md` (SDD workflow, dev policies)
- `.github/CODEOWNERS` (optional) [NEEDS CLARIFICATION: owners?]

### Key Entities *(include if feature involves data)*
- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [ ] Avoids tooling-specific implementation steps; focuses on policy and workflow
- [ ] Written clearly for contributors and AI assistants
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] No unresolved [NEEDS CLARIFICATION] markers remain (decide on `.local`, CODEOWNERS)
- [ ] Requirements are testable and unambiguous  
- [ ] Success criteria are measurable (templates/guidance present and consistent)
- [ ] Scope is clearly bounded (guidance + templates; no CI configuration)
- [ ] Dependencies and assumptions identified (CLAUDE guidance as baseline)

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [ ] Entities identified (finalize owners for CODEOWNERS if used)
- [ ] Review checklist passed

---
