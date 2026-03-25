# Oh My PBI 🎨

> A GitHub Copilot agent for Power BI & Microsoft Fabric — no CLI expertise required.

**Oh My PBI** is a local-repo Copilot agent that guides non-technical Power BI / Microsoft Fabric users through their entire daily workflow: git housekeeping, development, quality review, conventional commits, and documentation — all without typing a single git command.

## ✨ What it does

| Phase | What happens |
|-------|-------------|
| **1 · Git Housekeeping** | Clone/verify repo, fetch remotes, create/switch feature branch, keep workspace clean |
| **2 · Development** | PBI-aware guidance: DAX, data models, dataflows, Fabric pipelines, Power Query M |
| **3 · Quality Review** | Correctness → architecture → performance → presentation review fan-out |
| **4 · Git Close-out** | Conventional commit, push, open PR on the right branch |
| **5 · Documentation** | PR description, CHANGELOG entry, feature design note, DAX measure docs |

## 🛡️ Safety first

Oh My PBI will **hard-stop** before any irreversible operation:

- ❌ No direct pushes to `main`
- ❌ No `reset --hard`, `clean -fd`, `branch -D`, `rebase`, `amend`, or `--no-verify`
- ✅ Every destructive action requires explicit user confirmation
- ✅ Repo State Gate checks for detached HEAD / merge-in-progress before every write

## 🚀 Getting started

### Prerequisites

- [Git for Windows](https://git-scm.com/download/win)
- [GitHub CLI (`gh`)](https://cli.github.com/)
- [VS Code](https://code.visualstudio.com/) with [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)

### Setup

```powershell
# 1. Clone this repo into your Power BI project folder
gh repo clone yldgio/oh-my-pbi

# 2. Open in VS Code
code oh-my-pbi

# 3. Start your day
# Use the Command Palette → "Start Work" prompt, or just chat with @oh-my-pbi
```

### Starting a work session

Open Copilot Chat and type:

```
@oh-my-pbi start work on [feature name]
```

Or use the built-in prompt: **Command Palette** → `Copilot: Run Prompt` → `start-work`.

## 🧠 Agent architecture

```
.github/agents/
  oh-my-pbi.md          ← Main orchestrator (5-phase workflow)
  pbi-researcher.md     ← Doc verification subagent (haiku, microsoft-docs + context7)

.agents/skills/
  git-workflow.md       ← Branch, fetch, pull, push, stash (Windows PowerShell)
  git-commit/           ← Staging, conventional commits
  pbi-dataflows.md      ← Power Query M, dataflows gen1/gen2, Fabric pipelines
  documentation.md      ← PR descriptions, CHANGELOG, design notes, DAX docs
  powerbi-modeling/     ← Star schema, DAX, RLS, relationships, performance
  power-bi-dax-optimization/
  fabric-cli-core/      ← Fabric CLI reference
  fabric-cli-powerbi/   ← Power BI via Fabric CLI
  fabric-lakehouse/     ← Lakehouse operations
  microsoft-docs/       ← Microsoft Learn inline lookup
  gh-cli/               ← GitHub CLI operations
  az-devops-cli/        ← Azure DevOps CLI operations
```

## 📋 Skills lock

Installed skills are tracked in `skills-lock.json`. Hand-crafted skills (git-workflow, pbi-dataflows, documentation) live directly in `.agents/skills/`.

## 🤝 Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## 📄 License

MIT — see [LICENSE](LICENSE).
