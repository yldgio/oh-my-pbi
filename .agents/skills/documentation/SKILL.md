---
name: documentation
description: >
  Generate and maintain documentation artifacts for Power BI / Fabric work.
  Produces three outputs per feature: PR description (from git log + diff),
  CHANGELOG.md entry (Keep a Changelog format), and a docs/{feature}.md design
  note. Also covers DAX measure documentation and model change notes.
  Load when user says "document this", "write up what I did", or after a PR is opened.
license: MIT
allowed-tools: runCommands, editFiles
---

# Documentation — PR Descriptions, CHANGELOG, Feature Notes

## Overview

Every completed feature produces three documentation artifacts:

| Artifact | File | Purpose |
|----------|------|---------|
| PR description | GitHub / ADO PR body | What changed and why — for reviewers |
| CHANGELOG entry | `CHANGELOG.md` | Project history for stakeholders |
| Feature design note | `docs/{feature-name}.md` | Technical record for future maintainers |

---

## Part 1 — PR Description

### Gather context from git

```powershell
# Commits on this branch (not on base)
$baseBranch = git remote show origin | Select-String "HEAD branch" | ForEach-Object { ($_ -split ":\s*")[1].Trim() }
git log origin/$baseBranch..HEAD --oneline

# Files changed
git diff --stat origin/$baseBranch..HEAD

# Full diff (for analysis)
git diff origin/$baseBranch..HEAD
```

### PR Description Template

```markdown
## Summary

<!-- 1-2 sentences: what changed and why -->
[Short summary of the feature or fix and the business reason for it]

## Changes

### Semantic Model
<!-- List measures, tables, or relationships added/modified/removed -->
- Added measure: `Sales YTD` — year-to-date revenue using TOTALYTD
- Modified relationship: `FactSales[DateKey]` → `DimDate[DateKey]` (active, many-to-one)

### Reports
<!-- List pages, visuals, or interactions changed -->
- Added page: "YTD Performance" with KPI cards and line chart
- Modified visual: Bar chart on "Monthly Sales" now uses `Sales YTD` measure

### Dataflows / Pipelines
<!-- Only if applicable -->
- (none)

### Other
<!-- .gitignore changes, CHANGELOG, documentation -->
- Updated CHANGELOG.md
- Added docs/sales-ytd-feature.md

## Business Impact

<!-- What does this change enable or improve for users? -->
[Plain language: what can users now do that they couldn't before?]

## Testing Done

- [ ] Opened in Power BI Desktop — no errors
- [ ] Report renders correctly in Fabric workspace
- [ ] Key measures validated against source data
- [ ] No hardcoded credentials in Power Query
- [ ] JSON files are valid (no lint errors)

## Notes for Reviewers

<!-- Anything a reviewer should pay special attention to -->
[Optional — edge cases, known limitations, related future work]
```

### Populating from git log

```powershell
# Auto-generate changes section from commit messages
$commits = git log origin/$baseBranch..HEAD --pretty=format:"%s"
$commits | ForEach-Object { "- $_" }

# Categorize changed files
$changedFiles = git diff --name-only origin/$baseBranch..HEAD
$modelFiles = $changedFiles | Where-Object { $_ -match "\.bim$|SemanticModel|\.tmdl$" }
$reportFiles = $changedFiles | Where-Object { $_ -match "\.pbir$|Report/" }
$dataflowFiles = $changedFiles | Where-Object { $_ -match "DataflowRefreshable|mashup\.json" }
$pipelineFiles = $changedFiles | Where-Object { $_ -match "DataPipeline|pipeline-content\.json" }
```

---

## Part 2 — CHANGELOG.md

### Format: Keep a Changelog

The CHANGELOG.md file follows [Keep a Changelog](https://keepachangelog.com/) conventions.

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.2.0] - 2025-01-15

### Added
- `Sales YTD` measure: year-to-date revenue using TOTALYTD with calendar intelligence
- `MTD Revenue` measure: month-to-date revenue comparison
- "YTD Performance" report page with KPI cards

### Changed
- `Sales Total` measure: improved CALCULATE filter context handling
- Date table relationship now uses active cross-filter

### Fixed
- Fixed `Customer Count` measure double-counting in multi-region scenarios

### Removed
- Removed deprecated `OldRevenueMeasure` (replaced by `Sales Total`)
```

### Entry Types

| Type | Use for |
|------|---------|
| `Added` | New measures, tables, visuals, pages, features |
| `Changed` | Modified existing items |
| `Fixed` | Bug fixes (wrong values, broken visuals) |
| `Removed` | Deleted measures, tables, columns, pages |
| `Deprecated` | Items that will be removed in a future update |
| `Security` | Fixes to RLS, permission, or data exposure issues |

### Append workflow

```powershell
# Read current CHANGELOG
$changelog = Get-Content "CHANGELOG.md" -Raw

# Find the [Unreleased] section
$unreleasedPattern = "## \[Unreleased\]"
$insertionPoint = $changelog.IndexOf($unreleasedPattern) + "## [Unreleased]".Length

# New entry to insert
$newEntry = @"

### Added
- $newFeatureDescription

"@

# Insert after [Unreleased] header
$updatedChangelog = $changelog.Substring(0, $insertionPoint) + $newEntry + $changelog.Substring($insertionPoint)
$updatedChangelog | Set-Content "CHANGELOG.md"
```

### Initialize CHANGELOG.md (if not present)

```powershell
$template = @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

"@
$template | Set-Content "CHANGELOG.md"
```

---

## Part 3 — Feature Design Note

### Location: `docs/{feature-name}.md`

```powershell
# Create docs directory if needed
New-Item -ItemType Directory -Force "docs" | Out-Null

# Feature name from branch name
$branchName = git branch --show-current
$featureName = $branchName -replace "^feature/", ""
$docPath = "docs/$featureName.md"
```

### Feature Design Note Template

```markdown
# {Feature Name}

**Date:** {YYYY-MM-DD}
**Branch:** {branch-name}
**PR:** #{pr-number}
**Author:** {name}

## What Was Built

<!-- Plain English: what does this feature add or change? -->
[Description for someone who wasn't in the room]

## Why It Was Built

<!-- Business context: what problem does this solve? -->
[The business reason — what users needed]

## Key Decisions

<!-- Important design choices and why they were made -->

### Measure Design
- Used `TOTALYTD` instead of CALCULATE+DATESYTD for consistency with existing measures
- Date intelligence relies on the `DimDate` table marked as Date Table

### Model Structure
- Added calculated column to `FactSales` for bucketing (could not be done in PQ due to folding concerns)
- No new relationships added — existing date relationship handles all scenarios

### Report Design
- Chose KPI cards over gauges for YTD (cleaner on mobile layout)
- Color palette follows existing brand variables (from Theme.json)

## Measures Added / Changed

| Measure | Table | Description |
|---------|-------|-------------|
| `Sales YTD` | FactSales | Year-to-date revenue: `TOTALYTD([Sales Total], DimDate[Date])` |
| `Sales MTD` | FactSales | Month-to-date revenue: `TOTALMTD([Sales Total], DimDate[Date])` |

## Known Limitations

<!-- Anything that is not perfect but was acceptable for v1 -->
- YTD calculation uses fiscal year (April–March); standard calendar year requires parameter change
- No mobile layout for new page (deferred)

## Future Improvements

<!-- What could be done next -->
- Add prior year comparison measures (`Sales YTD PY`, `Sales YTD vs PY %`)
- Mobile layout for "YTD Performance" page
```

---

## Part 4 — DAX Measure Documentation

When adding measures to a model, document them inline using Tabular Model description fields.

### Format for measure descriptions

```
[Brief purpose — 1 sentence]
Formula pattern: [TOTALYTD / CALCULATE+FILTER / etc.]
Depends on: [DimDate[Date], FactSales[Amount]]
```

### Bulk measure documentation checklist

For every new measure added in a feature:
- [ ] Description set in the model (Tabular Editor or Power BI Desktop Properties pane)
- [ ] Home Table is correct (not the default)
- [ ] Display Folder is set (group related measures)
- [ ] Format String is appropriate (Currency, %, 0.00, etc.)
- [ ] Added to the CHANGELOG entry

---

## Part 5 — Documentation Checklist

Run at the end of every Phase 5 (Documentation):

```
[ ] PR description written and attached to PR
[ ] CHANGELOG.md updated (entry under [Unreleased])
[ ] docs/{feature-name}.md created
[ ] All new measures have descriptions in the model
[ ] No TODO/FIXME comments left in JSON files
[ ] .gitignore updated if new file types introduced
```
