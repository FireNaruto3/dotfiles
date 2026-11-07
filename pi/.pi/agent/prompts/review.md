---
description: Review changes for bugs and regressions without editing
argument-hint: "[focus or scope]"
---
Review the current changes. Focus or scope: ${@:-correctness, security, and regressions in the current git diff}.

- Read the applicable project instructions and inspect both staged and unstaged changes, plus relevant surrounding code. Include relevant untracked source files when present.
- Do not modify files, stage changes, commit, push, or run commands that change state.
- Prioritize actionable bugs over stylistic preferences. Explain the failure scenario and impact for each finding.
- Report findings in severity order with file paths and line numbers.
- Separate confirmed findings from uncertainties and identify any validation gaps.
- If no actionable findings are identified, say so explicitly and note residual risks rather than inventing issues.

This template supplies behavioral instructions, not an enforced tool-permission boundary.
