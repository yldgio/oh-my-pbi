---
name: git-workflow
description: >
  Operazioni git fondamentali per progetti Power BI / Fabric su Windows.
  Usa quando l'utente chiede di: creare un branch, cambiare branch, sincronizzare,
  aggiornare il branch, fare push, stashare il lavoro, salvare temporaneamente,
  clonare o inizializzare un repo — anche in italiano: "crea un branch", "cambia branch",
  "manda le modifiche", "sincronizza con main", "salva il lavoro temporaneamente",
  "aggiorna il branch", "stash". Include: Repo State Gate, rilevamento remoto
  (GitHub / Azure DevOps), guardrail di sicurezza, configurazione Windows.
  Delega la creazione commit a git-commit, PR/issue a gh-cli o az-devops-cli.
  Tutti i comandi sono PowerShell-native.
license: MIT
allowed-tools: runCommands
---

# Git Workflow — Operazioni Core

## Quando Usare

Usa `git-workflow` quando l'utente:
- Vuole **creare o cambiare branch** ("crea un branch", "passa al branch X")
- Vuole **aggiornare/sincronizzare** il branch ("sincronizza con main", "pull", "aggiorna")
- Vuole **fare push** ("manda le modifiche", "push", "carica su GitHub")
- Vuole **stashare** il lavoro ("salva temporaneamente", "metti da parte le modifiche")
- Vuole **clonare o inizializzare** un repo
- Ha bisogno di **rilevare il remoto** (GitHub vs Azure DevOps)

**Delega sempre ad altri skill:**
- Messaggio di commit → `git-commit`
- PR/issue/Actions GitHub → `gh-cli`
- PR/pipeline/work item Azure DevOps → `az-devops-cli`
- Rebase interattivo o riscrittura storia → admin mode

---

## Quick Reference

| Operazione | Comando PowerShell |
|------------|-------------------|
| Crea branch | `git checkout -b "feature/nome" origin/main` |
| Cambia branch | `git fetch origin && git checkout nome-branch` |
| Aggiorna branch | `git pull --rebase origin nome-branch` |
| Stash | `git stash push -m "descrizione"` |
| Ripristina stash | `git stash apply stash@{0}` |
| Controlla stato | `git status` (sempre sicuro) |
| Lista branch | `git branch -v` |
| Fetch aggiornamenti | `git fetch origin` (sempre sicuro) |

---

## Repo State Gate

**Esegui prima di ogni operazione di scrittura** (crea branch, pull --rebase, push, commit, crea PR).

```powershell
# 0. Verifica che siamo dentro un repository git
git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⛔ STOP: Questa cartella non è un repository git."
    Write-Host "   Opzioni:"
    Write-Host "   • Inizializza un nuovo repo : git init"
    Write-Host "   • Clona un repo esistente   : git clone <url>"
    Write-Host "   Dimmi cosa preferisci fare."
    return
}

# 1. Verifica operazioni in corso (merge/rebase/cherry-pick)
$gitDir = git rev-parse --git-dir 2>$null
$mergeHead  = Test-Path "$gitDir/MERGE_HEAD"
$rebaseDir  = (Test-Path "$gitDir/rebase-merge") -or (Test-Path "$gitDir/rebase-apply")
$cherryPick = Test-Path "$gitDir/CHERRY_PICK_HEAD"

if ($mergeHead -or $rebaseDir -or $cherryPick) {
    Write-Host "⛔ STOP: C'è già un'operazione in corso (merge/rebase/cherry-pick)."
    Write-Host "   Risolvila prima di continuare."
    return
}

# 2. Verifica detached HEAD
$headRef = git symbolic-ref HEAD 2>$null
if (-not $headRef) {
    Write-Host "⛔ STOP: Il repository è in stato 'detached HEAD'."
    Write-Host "   Esegui: git checkout <nome-branch>  per tornare su un branch."
    return
}

# 3. Verifica branch protetti
$branch = git branch --show-current
$protectedBranches = @("main", "master", "develop")
if ($protectedBranches -contains $branch) {
    Write-Host "⛔ STOP: Sei su '$branch'."
    Write-Host "   Non è consentito lavorare direttamente su un branch protetto."
    Write-Host "   Dimmi su cosa stai lavorando e creo un feature branch."
    return
}

# 4. Verifica upstream
$upstream = git rev-parse --abbrev-ref "@{upstream}" 2>$null
if (-not $upstream) {
    Write-Host "⚠️  ATTENZIONE: Il branch corrente non ha un upstream configurato."
    Write-Host "   Il primo push richiederà: git push --set-upstream origin $branch"
}

# 5. Stato attuale
$remote = (git remote -v 2>$null | Select-Object -First 1)
Write-Host "✅ Stato repo: branch=$branch | upstream=$upstream | remote=$remote"
```

**Stop immediato:**
- **Cartella non è un repo git** (step 0) · Merge in corso · Rebase in corso · Cherry-pick in corso · Detached HEAD

**Avvisi (comunica e chiedi conferma):**
- Nessun upstream tracking
- Branch locale indietro rispetto al remoto
- Clone superficiale (`git rev-parse --is-shallow-repository`)

---

## Inizializza o Clona un Repo

Usa questa sezione quando il Repo State Gate rileva che **non siamo in un repo git** (step 0 fallisce).

### Clona un repo esistente

```powershell
# Chiedi l'URL del repo all'utente, poi:
git clone <url> .          # clona nella cartella corrente
# oppure
git clone <url> nome-dir   # clona in una nuova cartella

# Verifica
git --no-pager log --oneline -3
git remote -v
```

### Inizializza un nuovo repo locale

```powershell
git init
git branch -M main         # rinomina il branch di default in main

# Aggiungi un remoto (se l'utente ne ha uno)
git remote add origin <url>
git fetch origin

# Primo commit se ci sono già file
git add .
# → delega il messaggio di commit alla skill git-commit
```

**Dopo init/clone:** esegui nuovamente il Repo State Gate per verificare lo stato pulito prima di procedere.

---

## Rilevamento Remoto

```powershell
function Get-GitRemoteHost {
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) {
        Write-Host "Nessun remoto 'origin' trovato. Chiedi all'utente di specificarlo."
        return "unknown"
    }
    if ($remoteUrl -match "github\.com")                        { return "github" }
    if ($remoteUrl -match "dev\.azure\.com|visualstudio\.com") { return "azuredevops" }
    Write-Host "⚠️ URL remoto non riconosciuto: $remoteUrl"
    return "unknown"
}
```

| Pattern | Host rilevato | Tool per PR |
|---------|--------------|-------------|
| `github.com` | GitHub | skill `gh-cli` |
| `dev.azure.com` o `visualstudio.com` | Azure DevOps | skill `az-devops-cli` |
| Altro / più remoti | Chiedi all'utente | Guida manuale |

Se `git remote -v` mostra più remoti: mostrali all'utente e chiedi quale usare prima di qualsiasi push.

---

## Operazioni Branch

### Crea feature branch

```powershell
# Rileva branch base dal remoto
$baseBranch = git remote show origin 2>$null |
    Select-String "HEAD branch" |
    ForEach-Object { ($_ -split ":\s*")[1].Trim() }
if (-not $baseBranch) { $baseBranch = "main" }

# Crea e passa al nuovo branch
git checkout -b "feature/$featureName" origin/$baseBranch
```

**Regole:**
- Formato: `feature/{descrizione-breve}` (minuscolo, solo trattini)
- Sempre da `origin/main` (stato fresco), mai da `main` locale
- Mai creare un branch in detached HEAD (esegui prima il Repo State Gate)

### Passa a branch esistente

```powershell
git fetch origin
git checkout $branchName
git branch --set-upstream-to="origin/$branchName" $branchName
```

---

## Fetch e Pull

### Fetch (sempre sicuro)

```powershell
git fetch origin
git status   # Mostra quanti commit sei avanti/indietro
```

### Pull sicuro (con guardrail rebase)

```powershell
# Guardrail: working tree deve essere pulito
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️ Ci sono modifiche non committate. Fai stash o commit prima del pull."
    Write-Host "File modificati:"
    $status | ForEach-Object { Write-Host "  $_" }
    return
}

git pull --rebase origin $branchName
if ($LASTEXITCODE -ne 0) {
    Write-Host "⛔ Pull fallito — probabilmente un conflitto di rebase."
    Write-Host "   Opzioni:"
    Write-Host "   1. Risolvi i conflitti nei file elencati, poi: git rebase --continue"
    Write-Host "   2. Annulla e torna allo stato precedente: git rebase --abort"
    Write-Host "   Non continuare con altro lavoro finché non è risolto."
}
```

**Non usare `git pull --rebase` se:**
- Il working tree non è pulito
- C'è già un rebase in corso

### Risoluzione Conflitti di Rebase

Se `git pull --rebase` fallisce con conflitti:

```powershell
# 1. Vedi i file in conflitto
git status

# 2. Per ogni file: apri, risolvi i marcatori (<<<<<<< | ======= | >>>>>>>)

# 3. Aggiungi i file risolti
git add <file-risolto>

# 4. Continua il rebase
git rebase --continue

# 5. Verifica completamento
git log --oneline -5
```

**Per annullare e ricominciare:**
```powershell
git rebase --abort
git status   # Torna allo stato pre-pull
```

---

## Push

```powershell
# 1. Valida remoto
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Write-Host "⛔ STOP: Nessun remoto 'origin' trovato."
    Write-Host "   Aggiungilo prima: git remote add origin <url>"
    return
}

# 2. Mostra destinazione e attendi conferma esplicita
$branch = git branch --show-current
Write-Host "Sto per inviare le modifiche a:"
Write-Host "  Remoto : $remote"
Write-Host "  Branch : $branch"
# OBBLIGATORIO: chiedi conferma con ask_user o equivalente.
# Non eseguire il push senza risposta affermativa dell'utente.
```

```powershell
# Primo push (imposta upstream)
git push --set-upstream origin $branch

# Push successivi
git push origin $branch
```

**Blocchi assoluti:**
- `git push --force` → **SEMPRE BLOCCATO**. Offri `--force-with-lease` solo se l'utente spiega il motivo
- Push su `main`/`master`/`develop` → **STOP IMMEDIATO**. Offri un feature branch
- Push su remoto sconosciuto → **STOP IMMEDIATO**. Conferma destinazione prima

---

## Stash

```powershell
# Salva (sempre con nome)
git stash push -m "$descrizione"
Write-Host "Salvato: $descrizione"
Write-Host "Per ripristinare: git stash apply stash@{0}"

# Lista
git stash list

# Ripristina (preferisci apply per conservare lo stash)
git stash apply stash@{0}
# Usa pop solo se l'utente vuole rimuovere lo stash dalla lista

# BLOCCO: stash drop e stash clear
Write-Host "⚠️ Stai per eliminare definitivamente del lavoro salvato."
Write-Host "Contenuto dello stash:"
git stash show -p stash@{0}
Write-Host "Non è reversibile. Scrivi 'ELIMINA' per confermare:"
```

**Regole:**
- Dai sempre un nome allo stash (`-m "descrizione"`)
- Preferisci `apply` a `pop` (apply conserva lo stash come backup)
- `stash drop` e `stash clear` richiedono anteprima + conferma esplicita

---

## Regole di Sicurezza

| Comando | Perché bloccato | Alternativa sicura |
|---------|----------------|-------------------|
| `git push --force` | Distrugge la storia remota | `git push --force-with-lease` (con spiegazione) |
| `git reset --hard` | Distrugge lavoro non committato | Prima `git stash push`, poi reset |
| `git clean -fd` / `-fdx` | Elimina file non tracciati | Mostra anteprima; conferma file per file |
| `git restore <file>` | Scarta modifiche locali in silenzio | Mostra diff prima; conferma per file |
| `git branch -D` | Elimina branch anche se non merged | Verifica prima se è merged |
| `git stash drop/clear` | Perde lavoro in modo permanente | Mostra contenuto prima |
| `git commit --amend` | Riscrive storia (pericoloso se già pushato) | Solo admin mode |
| `git rebase -i` | Riscrittura interattiva su branch condivisi | Solo admin mode |
| `--no-verify` | Bypassa hook e policy locali | Mai — correggi ciò che l'hook segnala |
| Commit diretto su `main`/`master`/`develop` | **STOP** | Crea un feature branch |

---

## Troubleshooting

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| "Permission denied (publickey)" | Autenticazione SSH fallita | `ssh -T git@github.com`; potrebbe servire `gh auth login` |
| "failed to push some refs" | Branch locale indietro rispetto al remoto | Prima `git pull --rebase`, poi riprova il push |
| "rejected by hook" | Hook ha bloccato l'operazione | Correggi il problema segnalato dall'hook |
| "detached HEAD" | Checkout su un commit, non su un branch | `git checkout <nome-branch>` |
| "shallow repository" | Clone con `--depth` | `git fetch --unshallow` per storia completa |
| Credenziali scadute | Token GCM o SSH expirato | Per GitHub: `gh auth login`; per ADO: `az devops configure` |

---

## Note Windows

```powershell
# Line ending consigliato (LF su commit, CRLF su checkout)
git config --global core.autocrlf true

# File JSON Fabric — forza sempre LF (aggiungi a .gitattributes)
# *.json text eol=lf

# Path con spazi — usa sempre le virgolette
git add "cartella con spazi/file.json"

# Percorsi lunghi (Windows 10/11)
git config --global core.longpaths true

# Test connettività remoto prima della prima operazione
git ls-remote origin HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Impossibile raggiungere il remoto. Verifica autenticazione."
    Write-Host "   GitHub: gh auth status"
    Write-Host "   Azure DevOps: az devops configure --list"
}
```

---

## Fallback PowerShell per git-commit

Il skill `git-commit` usa Bash. Su Windows senza Bash disponibile:

```powershell
$bashAvailable = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bashAvailable) {
    # Delega la generazione del messaggio a git-commit,
    # ma esegui il commit direttamente in PowerShell
    git add $filePaths
    git commit -m $commitMessage
}
```
