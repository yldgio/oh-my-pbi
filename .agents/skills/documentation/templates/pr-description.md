## Summary

<!-- 1-2 sentences: what changed and why -->
[Short summary of the feature or fix and the business reason for it]

## Changes

### Semantic Model
<!-- List measures, tables, relationships added/modified/removed -->
<!-- Use "Semantic Model" — NOT "Data Model" or "Dataset" -->
- Added measure: `Measure Name` — brief description
- Modified relationship: `Table[Key]` → `DimTable[Key]` (active, many-to-one)

### Reports
<!-- List pages, visuals, or interactions changed -->
- Added page: "Page Name" with [visual types]
- Modified visual: [visual] on "[Page]" now uses `[Measure]`

### Dataflows / Pipelines
<!-- Only if applicable — delete section if not used -->
- (none)

### Other
<!-- .gitignore changes, CHANGELOG, documentation -->
- Updated CHANGELOG.md
- Added docs/[feature-name].md

## Business Impact

<!-- What can users now do that they couldn't before? Plain language. -->
[Plain language: what does this unlock for the business?]

## Testing Done

- [ ] Opened in Power BI Desktop — no errors
- [ ] Report renders correctly in Fabric workspace
- [ ] Key measures validated against source data
- [ ] No hardcoded credentials in Power Query
- [ ] JSON files are valid (no lint errors)

## Notes for Reviewers

<!-- Optional — edge cases, known limitations, related future work -->
[Leave blank or delete this section if nothing to flag]
