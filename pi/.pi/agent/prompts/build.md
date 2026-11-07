---
description: Implement an approved plan and run relevant checks
argument-hint: "[task or plan]"
---
Work in implementation mode for this request: ${@:-the approved plan discussed above}.

- Follow the applicable project instructions.
- If no approved plan or explicit implementation request is available, ask what to implement before making changes.
- Inspect the working tree first and preserve unrelated changes. Prefer small, focused edits over broad refactors.
- Implement the requested changes and keep affected documentation synchronized.
- Ask before deleting saved application data, making destructive changes outside the approved scope, or changing system-wide settings.
- Run relevant checks that are safe for the current environment. Do not trigger interactive or hardware-sensitive operations merely to validate syntax.
- Summarize the changes, checks performed, and any remaining limitations.
- Do not stage, commit, or push unless explicitly requested.

This template supplies behavioral instructions, not an enforced tool-permission boundary.
