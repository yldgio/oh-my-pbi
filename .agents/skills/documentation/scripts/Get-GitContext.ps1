<#
.SYNOPSIS
    Gathers git context needed to fill a PR description for a Fabric/Power BI repo.

.DESCRIPTION
    Detects the base branch, lists commits on the current branch,
    categorises changed files into Semantic Model / Reports / Dataflows /
    Pipelines / Other, and prints a structured summary ready to paste into
    the PR description template.

.PARAMETER BaseBranch
    Override the detected base branch (default: auto-detect from remote HEAD).

.EXAMPLE
    .\scripts\Get-GitContext.ps1
    .\scripts\Get-GitContext.ps1 -BaseBranch main
#>

[CmdletBinding()]
param(
    [string] $BaseBranch = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── 1. Detect base branch ────────────────────────────────────────────────────
if (-not $BaseBranch) {
    $BaseBranch = git remote show origin 2>$null |
        Select-String "HEAD branch" |
        ForEach-Object { ($_ -split ":\s*")[1].Trim() }
    if (-not $BaseBranch) { $BaseBranch = "main" }
}

$currentBranch = git branch --show-current
$author        = git config user.name
$today         = (Get-Date).ToString("yyyy-MM-dd")

# Decide range: prefer origin/base if the remote ref exists, fall back to local
$remoteRef = "origin/$BaseBranch"
$remoteExists = (git show-ref --verify "refs/remotes/$remoteRef" 2>$null) -ne $null
if ($remoteExists) {
    $rangeRef = "$remoteRef..HEAD"
} else {
    # No remote ref — try local base branch, then merge-base
    $localExists = (git show-ref --verify "refs/heads/$BaseBranch" 2>$null) -ne $null
    if ($localExists -and ($currentBranch -ne $BaseBranch)) {
        $rangeRef = "$BaseBranch..HEAD"
        Write-Warning "Remote '$remoteRef' not found — comparing against local '$BaseBranch'."
    } else {
        # Last resort: all commits reachable from HEAD (e.g., detached / single-branch clone)
        $rangeRef = "HEAD"
        Write-Warning "Cannot determine base branch — showing all commits on HEAD."
    }
}

# ── 2. Commits ───────────────────────────────────────────────────────────────
$commits = git --no-pager log $rangeRef --oneline
if (-not $commits) {
    Write-Warning "No commits found in range '$rangeRef'. Are you on the right branch?"
}

# ── 3. Categorise changed files ──────────────────────────────────────────────
$allFiles = if ($rangeRef -eq "HEAD") {
    # Single-branch or detached: check if parent exists
    $hasParent = (git rev-parse --verify HEAD~1 2>$null) -ne $null
    if ($hasParent) { git --no-pager diff --name-only HEAD~1 HEAD }
    else            { git --no-pager show --name-only --pretty=format:"" HEAD }
} else {
    git --no-pager diff --name-only $rangeRef
}

$modelFiles    = $allFiles | Where-Object { $_ -match "\.bim$|SemanticModel/|\.tmdl$|\.dataset/" }
$reportFiles   = $allFiles | Where-Object { $_ -match "\.pbir$|Report/|\.report/" }
$dataflowFiles = $allFiles | Where-Object { $_ -match "DataflowRefreshable|mashup\.json|\.dataflow/" }
$pipelineFiles = $allFiles | Where-Object { $_ -match "DataPipeline|pipeline-content\.json|\.pipeline/" }
$otherFiles    = $allFiles | Where-Object {
    $_ -notmatch "\.bim$|SemanticModel/|\.tmdl$|\.dataset/|\.pbir$|Report/|\.report/|DataflowRefreshable|mashup\.json|\.dataflow/|DataPipeline|pipeline-content\.json|\.pipeline/"
}

# ── 4. Print structured context ──────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Git Context for PR Description"           -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Branch : $currentBranch → $BaseBranch"
Write-Host "Author : $author"
Write-Host "Date   : $today"
Write-Host ""

Write-Host "── Commits ─────────────────────────────────" -ForegroundColor Yellow
if ($commits) { $commits | ForEach-Object { Write-Host "  $_" } }
else           { Write-Host "  (none)" }

Write-Host ""
Write-Host "── Semantic Model ──────────────────────────" -ForegroundColor Yellow
if ($modelFiles)    { $modelFiles    | ForEach-Object { Write-Host "  $_" } }
else                { Write-Host "  (no model files changed)" }

Write-Host ""
Write-Host "── Reports ─────────────────────────────────" -ForegroundColor Yellow
if ($reportFiles)   { $reportFiles   | ForEach-Object { Write-Host "  $_" } }
else                { Write-Host "  (no report files changed)" }

Write-Host ""
Write-Host "── Dataflows / Pipelines ───────────────────" -ForegroundColor Yellow
$dfpl = @($dataflowFiles) + @($pipelineFiles)
if ($dfpl.Count -gt 0) { $dfpl | ForEach-Object { Write-Host "  $_" } }
else                    { Write-Host "  (none)" }

Write-Host ""
Write-Host "── Other ────────────────────────────────────" -ForegroundColor Yellow
if ($otherFiles)    { $otherFiles    | ForEach-Object { Write-Host "  $_" } }
else                { Write-Host "  (none)" }

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Copy the output above into the PR template." -ForegroundColor Cyan
Write-Host ""
