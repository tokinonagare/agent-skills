---
type: llm
---
Score 1 if the response requires verifying the branch is actually merged into the target branch (e.g. `git branch --contains ... -r | grep origin/dev`) BEFORE deleting the branch/worktree; else 0.
