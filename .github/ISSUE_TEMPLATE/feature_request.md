name: Feature request
description: Suggest an idea for Par6
title: "feat: <short description>"
labels: [feature]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem/Goal
      description: What problem are we solving? Who benefits and why?
    validations:
      required: true
  - type: textarea
    id: user-stories
    attributes:
      label: User Stories & Acceptance Criteria
      description: Provide 1-3 user stories with Given/When/Then acceptance criteria.
      placeholder: |
        As a <user>, I want <capability> so that <value>.
        Acceptance:
        - Given <state>, When <action>, Then <expected>
    validations:
      required: true
  - type: textarea
    id: constraints
    attributes:
      label: Constraints & Assumptions
      description: Any constraints, dependencies, or assumptions to consider?
  - type: checkboxes
    id: sdd
    attributes:
      label: Spec-Driven Development
      options:
        - label: I understand maintainers may convert this into a spec using scripts/create-new-feature.sh
          required: true
