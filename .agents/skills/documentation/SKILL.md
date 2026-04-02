---
name: documentation
description: >
  Generate and maintain documentation artifacts for Power BI / Fabric work.
  Every completed feature produces THREE artifacts together: PR description
  (from git log + diff), CHANGELOG.md entry (Keep a Changelog format), and a
  docs/{feature}.md design note. Also covers DAX measure documentation and
  model change notes. Load this skill whenever the user says "document this",
  "write up what I did", "write the PR description", "update the changelog",
  "add a changelog entry", "create release notes", "write the design doc",
  "document the measures", "write the PR body", "close out this feature",
  "documenta tutto", or after any feature work is complete and needs to be
  recorded. When the user asks to document a feature, always produce all three
  artifacts unless they explicitly ask for only one.
license: MIT
allowed-tools: runCommands, editFiles
---

# Documentation — PR Descriptions, CHANGELOG, Feature Notes

## Overview

Every completed feature produces **three documentation artifacts** — produce all three together unless the user explicitly asks for only one:

| Artifact | File | Purpose |
|----------|------|---------|
| PR description | GitHub / ADO PR body | What changed and why — for reviewers |
| CHANGELOG entry | `CHANGELOG.md` | Project history for stakeholders |
| Feature design note | `docs/{feature-name}.md` | Technical record for future maintainers |

> **Bundled resources in this skill:**
> - `scripts/Get-GitContext.ps1` — gathers git context (commits + categorised files) for the PR description
> - `scripts/Update-Changelog.ps1` — safely inserts entries into CHANGELOG.md
> - `templates/pr-description.md` — the PR description template to fill in

---

## Part 1 — PR Description

### Gather context from git — run this first

**Before filling any section of the PR template, run the bundled script:**

```powershell
.\.agents\skills\documentation\scripts\Get-GitContext.ps1
```

This prints commits, categorised changed files (Semantic Model / Reports / Dataflows / Other), branch, and author. Base all PR content on this output — do not populate from memory.

If the script is not accessible, fall back to running these commands directly:

```powershell
$baseBranch = git remote show origin | Select-String "HEAD branch" | ForEach-Object { ($_ -split ":\s*")[1].Trim() }
git --no-pager log origin/$baseBranch..HEAD --oneline
git --no-pager diff --stat origin/$baseBranch..HEAD
```

### PR Description Template

Read and fill in the template at `.agents\skills\documentation\templates\pr-description.md` (repo-root-relative path).

> **Important naming**: always use `### Semantic Model` (not "Data Model", "Dataset", or "DAX Measures") — this is the correct Power BI / Fabric term.

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

### Populating from git context

The output of `Get-GitContext.ps1` maps directly to the template sections:
- **Commits** → narrative for `## Summary` and entries under each `### Changes` subsection
- **Semantic Model files** → `### Semantic Model` bullets
- **Report files** → `### Reports` bullets
- **Dataflow/Pipeline files** → `### Dataflows / Pipelines` bullets

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

### Workflow

**Use the bundled script** — it handles file creation, the [Unreleased] guard, and correct insertion in one step:

```powershell
.\.agents\skills\documentation\scripts\Update-Changelog.ps1 `
    -Added   "Description of what was added" `
    -Changed "Description of what changed" `
    -Fixed   "Description of what was fixed"
```

Pass only the categories that apply. Multiple entries per category are supported:

```powershell
.\.agents\skills\documentation\scripts\Update-Changelog.ps1 `
    -Added "Sales YTD measure: year-to-date revenue using TOTALYTD" `
    -Added "YTD Performance report page with KPI cards and line chart"
```

The script automatically:
1. Creates `CHANGELOG.md` if it doesn't exist
2. Adds `## [Unreleased]` if the section is missing
3. Inserts entries under the correct category headers
4. Never duplicates or overwrites existing content

---

## Part 3 — Feature Design Note

### Location: `docs/{feature-name}.md`

```powershell
# Create docs directory if needed
New-Item -ItemType Directory -Force "docs" | Out-Null

# Derive feature name from branch — normalize to a URL-safe slug
$branchName  = git branch --show-current
$featureName = $branchName -replace "^(feature|bugfix|chore|fix)/", ""
$featureName = $featureName.ToLower() -replace "[^a-z0-9-]", "-" -replace "-{2,}", "-" -replace "^-|-$", ""
$docPath     = "docs/$featureName.md"

$today  = (Get-Date).ToString("yyyy-MM-dd")
$author = git config user.name
```

### Feature Design Note Template

```markdown
# {Feature Name}

**Date:** {today}
**Branch:** {branch-name}
**PR:** #{pr-number — fill in after PR is created, or TBD}
**Author:** {author from git config user.name}

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

> **Note:** This is a **development-time** task — measure descriptions should be set while building the model, not at documentation time. This skill checks at close-out that it was done, and fills any gaps if needed.

When adding measures to a model, document them inline using Tabular Model description fields.

### Format for measure descriptions

```
[Brief purpose — 1 sentence]
Formula pattern: [TOTALYTD / CALCULATE+FILTER / etc.]
Depends on: [DimDate[Date], FactSales[Amount]]
```

### Setting descriptions

If Tabular Editor CLI is available, descriptions can be set programmatically. Otherwise, note them as a manual step and provide the text to copy into the Properties pane in Power BI Desktop or Tabular Editor GUI.

### Bulk measure documentation checklist

For every new measure added in a feature:
- [ ] Description set in the model (Tabular Editor or Power BI Desktop Properties pane)
- [ ] Home Table is correct (not the default)
- [ ] Display Folder is set (group related measures)
- [ ] Format String is appropriate (Currency, %, 0.00, etc.)
- [ ] Added to the CHANGELOG entry

---

## Part 5 — Documentation Checklist

Run this at the end of every documentation session to confirm all artifacts are complete:

```
[ ] PR description written and attached to PR
[ ] CHANGELOG.md updated (entry under [Unreleased]) — ran Update-Changelog.ps1
[ ] docs/{feature-name}.md created with all sections filled
[ ] All new measures have descriptions in the model
[ ] No TODO/FIXME comments left in JSON files
[ ] .gitignore updated if new file types introduced
```

**When producing full documentation (all three artifacts), work through Parts 1 → 2 → 3 in order, then run this checklist before presenting output to the user.**
