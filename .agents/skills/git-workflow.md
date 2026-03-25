---
name: git-workflow
description: >
  Core git operations for Power BI / Fabric projects on Windows.
  Covers: repo init/clone, branching, fetch, pull, push, stash, remote
  detection, Repo State Gate, and safety guardrails. Delegates commit
  creation to git-commit skill, and PR/issue operations to gh-cli or
  az-devops-cli. All commands are PowerShell-native.
license: MIT
allowed-tools: runCommands
---

# Git Workflow — Core Operations

## Scope

This skill owns:
- Repository initialization and cloning
- Branch creation and switching
- Fetch, pull (with rebase safety check), push
- Stash lifecycle
- Remote host detection (GitHub vs Azure DevOps)
- Repo State Gate (pre-write safety check)
- Windows-specific git environment guidance

This skill does **NOT** own:
- Commit creation → delegate to `git-commit`
- GitHub PRs/issues/Actions → delegate to `gh-cli`
- Azure DevOps PRs/pipelines/work items → delegate to `az-devops-cli`

---

## Repo State Gate

**Run before every write operation** (branch create, pull --rebase, push, commit, PR create).

```powershell
# 1. Check for active conflict/rebase/merge operations
$gitDir = git rev-parse --git-dir 2>$null
$mergeHead = Test-Path "$gitDir/MERGE_HEAD"
$rebaseDir = (Test-Path "$gitDir/rebase-merge") -or (Test-Path "$gitDir/rebase-apply")
$cherryPick = Test-Path "$gitDir/CHERRY_PICK_HEAD"

if ($mergeHead -or $rebaseDir -or $cherryPick) {
    Write-Host "⛔ STOPPED: A merge, rebase, or cherry-pick is already in progress."
    Write-Host "   Resolve it first before continuing."
    return
}

# 2. Check for detached HEAD
$headRef = git symbolic-ref HEAD 2>$null
if (-not $headRef) {
    Write-Host "⛔ STOPPED: Repository is in detached HEAD state."
    Write-Host "   Run: git checkout <branch-name>  to return to a branch."
    return
}

# 3. Check upstream tracking
$upstream = git rev-parse --abbrev-ref "@{upstream}" 2>$null
if (-not $upstream) {
    Write-Host "⚠️  WARNING: Current branch has no upstream tracking branch."
    Write-Host "   First push will require: git push --set-upstream origin <branch>"
}

# 4. Report current state
$branch = git branch --show-current
$remote = (git remote -v 2>$null | Select-Object -First 1)
Write-Host "✅ Repo state: branch=$branch | upstream=$upstream | remote=$remote"
```

**Hard stops (block everything):**
- Merge in progress
- Rebase in progress
- Cherry-pick in progress
- Detached HEAD state

**Soft warnings (announce, ask to confirm):**
- No upstream tracking branch
- Local branch is behind remote (stale)
- Shallow clone detected (`git rev-parse --is-shallow-repository`)

---

## Remote Host Detection

```powershell
function Get-GitRemoteHost {
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) {
        Write-Host "No remote named 'origin' found. Ask user to specify remote."
        return "unknown"
    }
    if ($remoteUrl -match "github\.com") { return "github" }
    if ($remoteUrl -match "dev\.azure\.com|visualstudio\.com") { return "azuredevops" }
    Write-Host "⚠️ Unrecognized remote URL: $remoteUrl"
    return "unknown"
}
```

| Pattern | Detected host | PR tool |
|---------|--------------|---------|
| `github.com` | GitHub | `gh-cli` skill |
| `dev.azure.com` or `visualstudio.com` | Azure DevOps | `az-devops-cli` skill |
| Other / multiple remotes | Ask user | Manual guidance |

**Multiple remotes:** If `git remote -v` shows more than one remote, present them to the user and ask which is the team/PR remote before any push.

---

## Branch Operations

### Create feature branch

```powershell
# Discover default base branch from remote
$baseBranch = git remote show origin 2>$null | Select-String "HEAD branch" | ForEach-Object { ($_ -split ":\s*")[1].Trim() }
if (-not $baseBranch) { $baseBranch = "main" }

# Create and switch
git checkout -b "feature/$featureName" origin/$baseBranch
```

**Rules:**
- Branch name format: `feature/{short-description}` (lowercase, hyphens only)
- Never create directly from `main` local — always from `origin/main` (fresh state)
- Never create a branch while in detached HEAD (run Repo State Gate first)

### Switch to existing branch

```powershell
git fetch origin
git checkout $branchName
git branch --set-upstream-to="origin/$branchName" $branchName
```

---

## Fetch and Pull

### Safe fetch (always safe, no changes to working tree)

```powershell
git fetch origin
git status  # Show behind/ahead count
```

### Safe pull (with rebase guard)

```powershell
# Guard: working tree must be clean
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️ Uncommitted changes detected. Stash or commit before pulling."
    Write-Host "Changed files:"
    $status | ForEach-Object { Write-Host "  $_" }
    return
}

# Guard: no rebase/merge in progress (Repo State Gate covers this)

# Pull with rebase
git pull --rebase origin $branchName
if ($LASTEXITCODE -ne 0) {
    Write-Host "⛔ Pull failed — likely a rebase conflict."
    Write-Host "   Options:"
    Write-Host "   1. Resolve conflicts in the listed files, then: git rebase --continue"
    Write-Host "   2. Abort and return to previous state: git rebase --abort"
    Write-Host "   Do NOT continue with other work until this is resolved."
}
```

**Never use `git pull --rebase` if:**
- Working tree is dirty
- A rebase is already in progress
- User hasn't explicitly confirmed they understand rebase rewrites history

---

## Push

```powershell
# Always show destination before pushing
$branch = git branch --show-current
$remote = git remote get-url origin 2>$null
Write-Host "About to push to:"
Write-Host "  Remote: $remote"
Write-Host "  Branch: $branch"
Write-Host "Confirm? (y/n)"
# Wait for user confirmation

# First push (sets upstream)
git push --set-upstream origin $branch

# Subsequent pushes
git push origin $branch
```

**Hard blocks:**
- `git push --force` — **ALWAYS BLOCKED**. Offer `--force-with-lease` only if user explains why.
- Push to `main`/`master`/`develop` — **HARD STOP**. Explain why and offer feature branch instead.

---

## Stash Lifecycle

```powershell
# Save (always named)
git stash push -m "$stashDescription"
Write-Host "Stashed: $stashDescription"
Write-Host "To restore: git stash pop (or apply to keep stash)"

# List
git stash list

# Restore (prefer apply to preserve stash entry)
git stash apply stash@{0}
# Only use pop if user explicitly wants to remove from stash list

# HARD BLOCK: stash drop and stash clear
# Before allowing:
Write-Host "⚠️ You are about to permanently delete stashed work."
Write-Host "Stash contents:"
git stash show -p stash@{0}
Write-Host "This CANNOT be undone. Type 'DELETE' to confirm:"
```

**Rules:**
- Always name stashes (`-m "{description}"`)
- Prefer `apply` over `pop` (apply keeps the stash entry as backup)
- `stash drop` and `stash clear` require contents preview + explicit confirmation

---

## Safety Rules (Hard Blocks)

These operations are **blocked** unless the user explicitly requests them AND the agent explains consequences:

| Command | Why blocked | Safe alternative |
|---------|-------------|-----------------|
| `git push --force` | Destroys remote history; breaks teammates | `git push --force-with-lease` (with explanation) |
| `git reset --hard` | Permanently destroys uncommitted work | `git stash push` first, then reset |
| `git clean -fd` / `-fdx` | Deletes untracked files (may include exports) | Show preview first; confirm file by file |
| `git restore <file>` | Silently discards local changes | Show diff first; confirm per file |
| `git branch -D` | Deletes branch even if unmerged | Check merged status first |
| `git stash drop/clear` | Loses stashed work permanently | Show contents first |
| `git commit --amend` | Rewrites history (dangerous if already pushed) | Admin mode only |
| `git rebase -i` | Interactive rewrite (dangerous on shared branches) | Admin mode only |
| `--no-verify` | Bypasses hooks and local policy | Never; fix what the hook is catching |
| Direct commit to `main`/`master`/`develop` | **HARD STOP** | Create feature branch instead |

---

## Windows-Specific Notes

### Line ending configuration

```powershell
# Check current setting
git config core.autocrlf

# Recommended for Windows (convert to LF on commit, CRLF on checkout)
git config --global core.autocrlf true

# Fabric JSON files — enforce LF always (add to .gitattributes)
# *.json text eol=lf
```

### Git Credential Manager

Windows Git ships with Git Credential Manager (GCM). If prompted for credentials:

```powershell
# Check GCM is configured
git config --global credential.helper
# Should return: manager  (or manager-core on older installs)

# Force re-authentication
git credential reject
```

If HTTPS token has expired, GCM will prompt for a new one. The agent will wait for the user to complete the browser flow.

### Path handling

```powershell
# Always quote paths with spaces
git add "path with spaces/file.json"

# Check for long path support (Windows 10/11)
git config --global core.longpaths true
```

### Credential/auth check before first remote operation

```powershell
# Test remote connectivity without fetching
git ls-remote origin HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Cannot reach remote. This may require authentication."
    Write-Host "   For GitHub: run 'gh auth status' to check login state"
    Write-Host "   For Azure DevOps: run 'az devops configure --list'"
}
```

---

## git-commit Skill — PowerShell Fallback

The `git-commit` skill uses Bash. If Bash is not available on PATH, use these PS-native equivalents:

```powershell
# Check if bash is available
$bashAvailable = Get-Command bash -ErrorAction SilentlyContinue

if (-not $bashAvailable) {
    # PS-native commit (delegate to git-commit skill for message generation,
    # but execute the commit directly in PS)
    
    # Stage files
    git add $filePaths  # or: git add -A for all changes
    
    # Commit with message (agent generates message, user confirms)
    git commit -m $commitMessage
}
```

The `oh-my-pbi` orchestrator detects the shell environment at session start and uses the PS path when needed.
