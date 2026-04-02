<#
.SYNOPSIS
    Adds one or more entries to CHANGELOG.md under the [Unreleased] section.

.DESCRIPTION
    Ensures CHANGELOG.md exists, guarantees an [Unreleased] section is present,
    then inserts entries for each category provided. Safe to run multiple times.

.PARAMETER Added
    One or more "Added" bullet lines (without the leading dash).

.PARAMETER Changed
    One or more "Changed" bullet lines.

.PARAMETER Fixed
    One or more "Fixed" bullet lines.

.PARAMETER Removed
    One or more "Removed" bullet lines.

.PARAMETER Deprecated
    One or more "Deprecated" bullet lines.

.PARAMETER Security
    One or more "Security" bullet lines.

.PARAMETER Path
    Path to CHANGELOG.md. Defaults to CHANGELOG.md in the current directory.

.EXAMPLE
    .\scripts\Update-Changelog.ps1 `
        -Added   "Sales YTD measure: year-to-date revenue using TOTALYTD" `
        -Added   "YTD Performance report page with KPI cards and line chart" `
        -Changed "FactSales→DimDate relationship: now active cross-filter"

.EXAMPLE
    .\scripts\Update-Changelog.ps1 -Fixed "Customer Count double-counting in multi-region scenarios"
#>

[CmdletBinding()]
param(
    [string[]] $Added      = @(),
    [string[]] $Changed    = @(),
    [string[]] $Fixed      = @(),
    [string[]] $Removed    = @(),
    [string[]] $Deprecated = @(),
    [string[]] $Security   = @(),
    [string]   $Path       = "CHANGELOG.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── 1. Ensure file exists ────────────────────────────────────────────────────
if (-not (Test-Path $Path)) {
    @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

"@ | Set-Content $Path -Encoding UTF8
    Write-Host "Created $Path" -ForegroundColor Cyan
}

# ── 2. Read content ──────────────────────────────────────────────────────────
$content = Get-Content $Path -Raw -Encoding UTF8

# ── 3. Detect line ending style of existing content ─────────────────────────
$nl = if ($content -match "`r`n") { "`r`n" } else { "`n" }

# ── 4. Guard: add [Unreleased] if missing ───────────────────────────────────
$unreleasedHeader = "## [Unreleased]"
if ($content.IndexOf($unreleasedHeader) -lt 0) {
    # Insert after the first heading line (# Changelog)
    $content = $content -replace "(?m)^(# .+)(\r?\n)", "`$1`$2$($nl)$unreleasedHeader$nl"
    $content | Set-Content $Path -Encoding UTF8 -NoNewline
    $content = Get-Content $Path -Raw -Encoding UTF8
    # Verify insertion succeeded
    if ($content.IndexOf($unreleasedHeader) -lt 0) {
        throw "Failed to insert '$unreleasedHeader' into '$Path'. File may have a non-standard format — add the section manually and retry."
    }
    Write-Host "Added missing [Unreleased] section" -ForegroundColor Yellow
}

# ── 5. Build the block to insert ─────────────────────────────────────────────
$categoryOrder = [ordered]@{
    Added      = $Added
    Changed    = $Changed
    Deprecated = $Deprecated
    Removed    = $Removed
    Fixed      = $Fixed
    Security   = $Security
}

$newBlock = ""
foreach ($category in $categoryOrder.Keys) {
    # Skip empty or whitespace-only entries; force array so .Count is always valid
    $entries = @($categoryOrder[$category] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($entries.Count -gt 0) {
        $newBlock += "$nl### $category$nl"
        foreach ($entry in $entries) {
            $line = $entry.TrimStart("- ").Trim()
            $newBlock += "- $line$nl"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($newBlock)) {
    Write-Warning "No entries provided — nothing to insert."
    exit 0
}

# ── 6. Insert immediately after [Unreleased] header ─────────────────────────
$insertAt = $content.IndexOf($unreleasedHeader) + $unreleasedHeader.Length
$updated  = $content.Substring(0, $insertAt) + $newBlock + $content.Substring($insertAt)
$updated | Set-Content $Path -Encoding UTF8 -NoNewline

Write-Host "CHANGELOG.md updated successfully" -ForegroundColor Green
