---
name: git-commit
description: >
  Crea commit git semantici con messaggi Conventional Commits. Usa quando l'utente chiede
  di committare, salvare modifiche, o creare un commit — anche in italiano: "committa",
  "fai commit", "salva le modifiche su git", "crea un commit", "/commit",
  "metti in commit", "commit delle modifiche". Supporta: rilevamento automatico
  tipo/scope dal diff, generazione messaggio convenzionale, staging intelligente,
  trailer Co-authored-by obbligatorio, sintassi PowerShell nativa su Windows.
license: MIT
allowed-tools: Bash, runCommands
---

# Git Commit — Conventional Commits

## Quando Usare

Usa questo skill quando l'utente:
- Dice "committa", "fai un commit", "salva le modifiche", "crea un commit", "/commit"
- Ha modifiche staged o unstaged da salvare nel repository
- Vuole un messaggio di commit semantico/convenzionale

**Non usare** per:
- Visualizzare la cronologia commit → `git log`
- Modificare commit già pushati → admin mode
- Operazioni di branch o push → delega a `git-workflow`

---

## Formato Conventional Commit

```
<tipo>[scope opzionale]: <descrizione>

[body opzionale]

[footer opzionale]
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

> ⚠️ Il trailer `Co-authored-by` è **obbligatorio** su ogni commit. Non ometterlo mai.

## Tipi di Commit

| Tipo       | Uso                            |
| ---------- | ------------------------------ |
| `feat`     | Nuova funzionalità             |
| `fix`      | Correzione bug                 |
| `docs`     | Solo documentazione            |
| `style`    | Formattazione (nessuna logica) |
| `refactor` | Refactoring (no feat/fix)      |
| `perf`     | Miglioramento performance      |
| `test`     | Aggiunta/modifica test         |
| `build`    | Build/dipendenze               |
| `ci`       | Configurazione CI              |
| `chore`    | Manutenzione varia             |
| `revert`   | Revert di un commit            |

## Breaking Changes

```
# Punto esclamativo dopo tipo/scope
feat!: rimosso endpoint deprecato

# Footer BREAKING CHANGE
feat: la chiave 'extends' supporta array

BREAKING CHANGE: il comportamento di 'extends' è cambiato
```

---

## Workflow

### 1. Controlla Stato e Diff

**PowerShell (Windows — preferito):**
```powershell
git status --porcelain
git diff --staged   # Se ci sono file staged
git diff            # Modifiche non staged
```

**Bash:**
```bash
git status --porcelain
git diff --staged
git diff
```

**Casi speciali da gestire:**
- **Nessuna modifica** (working tree pulito) → avvisa l'utente, non procedere
- **File non tracciati (untracked)** → chiedi all'utente se includerli
- **Solo file staged** → usa `git diff --staged` per analisi

### 2. Staging (se necessario)

**PowerShell:**
```powershell
git add path/to/file1 path/to/file2   # File specifici
git add -A                             # Tutto
```

**Bash:**
```bash
git add path/to/file1 path/to/file2
git add -A
git add -p   # Staging interattivo per scegliere blocchi
```

> ⛔ Non committare mai: `.env`, credenziali, chiavi private, token API.

### 3. Genera il Messaggio

Analizza il diff per determinare:
- **Tipo**: Che tipo di modifica è?
- **Scope**: Quale area/modulo è coinvolto?
- **Descrizione**: Sintesi imperativa <72 caratteri

### 4. Mostra e Attendi Conferma *(obbligatorio)*

Prima di eseguire, mostra sempre il messaggio proposto:

```
📝 Messaggio di commit proposto:

feat(auth): aggiunge endpoint di login

Implementa autenticazione JWT con bcrypt per password hashing.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>

Procedo? [S/n]
```

Se l'utente vuole modificare: chiedi cosa cambiare e rigenera.

### 5. Esegui il Commit

**PowerShell (Windows):**
```powershell
git commit -m @"
feat(auth): aggiunge endpoint di login

Implementa autenticazione JWT con bcrypt.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
"@
```

**Bash:**
```bash
git commit -m "$(cat <<'EOF'
feat(auth): aggiunge endpoint di login

Implementa autenticazione JWT con bcrypt.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
EOF
)"
```

---

## Best Practices

- Un cambiamento logico per commit
- Imperativo presente: "aggiunge" non "aggiunto"
- Descrizione sotto i 72 caratteri
- Riferimento issues: `Closes #123`, `Refs #456`
- Il trailer `Co-authored-by` è sempre obbligatorio

---

## Sicurezza Git

- ❌ Non modificare `git config`
- ❌ Non usare `--force` o `reset --hard` senza richiesta esplicita
- ❌ Non bypassare hook (`--no-verify`) — mai
- ❌ Non fare force push su main/master
- ✅ Se il commit fallisce per un hook: correggi il problema, `git add`, crea un **nuovo** commit (non `--amend`)

---

## Troubleshooting

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| "nothing to commit, working tree clean" | Nessuna modifica | Verifica con `git status`; potrebbe essere già committato |
| Commit bloccato da pre-commit hook | Hook ha rilevato un problema | Correggi i file segnalati, `git add`, riprova |
| "please tell me who you are" | Identità git non configurata | `git config user.email "..."` e `git config user.name "..."` |
| Vuole modificare l'ultimo commit | Amend richiesto | Solo se **non** già pushato: `git commit --amend -m "..."` (admin mode) |
| Troppi file da committare | Diff molto grande | Suggerisci staging interattivo `git add -p` per commit logici |
