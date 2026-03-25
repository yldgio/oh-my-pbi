# Contributing to Oh My PBI

Thank you for helping make Oh My PBI better for Power BI and Fabric users!

## What can I contribute?

- **New skills** — cover a PBI/Fabric domain not yet in `.agents/skills/`
- **Skill improvements** — better patterns, safer PowerShell, more accurate DAX
- **Agent refinements** — workflow phase improvements, new safety guards
- **Documentation** — clearer instructions, better examples

## Ground rules

1. **Safety first.** Never weaken or bypass the Repo State Gate, Windows Environment Gate, or hard blocks in `oh-my-pbi.md` / `git-workflow.md`. If you think a hard block is wrong, open an issue first.
2. **Verify docs.** Any PBI/Fabric/DAX content must reference a Microsoft Learn URL. Use the `pbi-researcher` agent pattern.
3. **Keep files lean.** Skills should be 150–400 lines. If growing beyond that, split into a subdirectory with a `SKILL.md` entry point.
4. **Windows-first.** All shell examples must work in PowerShell 7+ on Windows. No `bash`-only patterns in skills.
5. **Conventional commits.** Use `feat:`, `fix:`, `docs:`, `refactor:`, `chore:` prefixes.

## Workflow

```
1. Fork → clone
2. git checkout -b feat/your-skill-name
3. Make changes
4. git commit -m "feat(skill): add pbi-xyz skill"
5. git push origin feat/your-skill-name
6. Open a PR — fill in the PR template
```

## Skill file format

New flat skills go in `.agents/skills/{name}.md`.  
Skills with reference sub-documents go in `.agents/skills/{name}/SKILL.md` with references in `.agents/skills/{name}/references/`.

Every skill must start with a YAML frontmatter block:

```yaml
---
name: my-skill
description: One-sentence description of what this skill provides.
---
```

## Questions?

Open an issue with the `question` label.
