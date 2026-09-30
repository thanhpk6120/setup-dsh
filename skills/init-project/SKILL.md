---
name: init-project
description: Initialize a non-git project workspace into a valid Git repository with a bootstrap README.md, committing ONLY README.md so VCS-dependent tools (Memorix, GitNexus) work properly.
---

# Init Project

Initialize a non-git project workspace into a valid Git repository.

**Triggers:** "init project", "init git", "khởi tạo git", "biến thư mục này thành git repo", "setup git repo", or when a tool explicitly requires a git repo and user asked to initialize it.

**Scope:** On-demand only. Never run automatically.

## Workflow

### Step 1: Check if already a git repo

```bash
git rev-parse --is-inside-work-tree
```

If output is `true`, report that the workspace is already a git repository and stop.

### Step 2: Initialize the repository

```bash
git init
```

### Step 3: Bootstrap README.md

Check if `README.md` exists in the workspace root.

- If missing, generate a concise README: project title derived from the folder name, plus a brief description (what, why, how).
- If `README.md` already exists, NEVER overwrite or mutate it.

### Step 4: Commit ONLY README.md (Strict Invariant)

```bash
git add README.md && git commit -m "chore: initialize project with README"
```

NEVER use `git add .` or `git add -A`. All other user files must stay untracked.

### Step 5: Verify

```bash
git log -1 --stat
git status --porcelain
```

- `git log -1 --stat` must show only `README.md`.
- `git status --porcelain` must show other files as untracked (`??`).
