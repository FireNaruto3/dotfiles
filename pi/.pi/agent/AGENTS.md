# Global Pi Preferences

## Communication

- Keep answers concise and direct. Show file paths clearly when discussing changes.
- Explain the cause of a bug before fixing it when the cause is known. Distinguish confirmed facts from assumptions.
- Ask clarifying questions when important requirements are ambiguous.

## Changes and Safety

- Read and follow applicable project instructions before working.
- Inspect the working tree first. Preserve unrelated work and prefer small, focused changes over broad refactors.
- For planning or review requests, inspect and report without changing files or running state-changing commands. Wait for explicit implementation approval after a plan.
- Ask before deleting saved application data, making destructive changes beyond the requested scope, or changing system-wide settings.
- Never request passwords or expose credentials. Do not add credentials, authentication files, session history, or other private runtime data to version control.
- Do not stage, commit, or push unless explicitly requested. Keep unrelated changes out of commits unless explicitly requested for inclusion.

## Validation and Reporting

- Keep affected documentation synchronized with implementation changes.
- Run relevant checks after editing when safe. Avoid interactive, destructive, or hardware-sensitive operations merely to validate syntax.
- Report what changed, which checks ran, and any failures or validation gaps. Do not claim checks passed unless they actually ran successfully.

These preferences and the `/plan`, `/build`, and `/review` templates guide model behavior; they are not enforced tool-permission boundaries.
