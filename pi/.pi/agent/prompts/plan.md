---
description: Investigate and propose a plan without changing files
argument-hint: "[task]"
---
Work in planning mode for this request: ${@:-the task discussed above}.

- Read the applicable project instructions and inspect relevant files.
- Do not edit, create, or delete files, install packages, change services, commit, or push.
- Use only inspection commands; avoid checks that write caches, build artifacts, or other state.
- Explain the current behavior and propose a focused implementation plan, including affected files, risks, and validation steps.
- Ask clarifying questions when needed rather than guessing important requirements.
- Stop after presenting the plan and wait for explicit approval before implementation.

This template supplies behavioral instructions, not an enforced tool-permission boundary.
