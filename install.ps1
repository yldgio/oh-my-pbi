<#
.SYNOPSIS
    Installs oh-my-pbi into an existing Power BI / Fabric git project.

.DESCRIPTION
    Downloads the oh-my-pbi workspace from GitHub and copies all required
    agent, skill, prompt, and MCP configuration files into the target project.
    No gh CLI required — pure PowerShell.

    Security note: this script downloads a ZIP over HTTPS from GitHub.
    Transport is secured by TLS; no additional hash pinning is performed for
    rolling main-branch installs. Pin to a tagged release for reproducible installs.

.PARAMETER Path
    Path to the target project folder. Defaults to the current directory.
    Must not contain wildcard characters.

.EXAMPLE
    # Run directly (installs into the current folder)
    irm https://raw.githubusercontent.com/yldgio/oh-my-pbi/main/install.ps1 | iex

.EXAMPLE
    # Install into a specific folder
    iex "& { $(irm https://raw.githubusercontent.com/yldgio/oh-my-pbi/main/install.ps1) } -Path C:\myproject"
#>

# Wrap everything in a function so that 'return' exits the function — not the
# host process. Calling 'exit' inside 'irm ... | iex' would close the terminal.
function Invoke-OhMyPbiInstall {
    [CmdletBinding()]
    param(
        [string]$Path = $PWD
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # ── Constants ────────────────────────────────────────────────────────────────
    $REPO_OWNER = 'yldgio'
    $REPO_NAME  = 'oh-my-pbi'
    $BRANCH     = 'main'
    $ZIP_URL    = "https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/heads/$BRANCH.zip"
    $TEMP_DIR   = Join-Path $env:TEMP "oh-my-pbi-install-$(Get-Random)"

    # Files/folders to copy: key = relative source path inside the extracted archive,
    # value = relative destination path inside the target project.
    # Entries ending with '/' are treated as directories (full replacement on overwrite).
    $MANIFEST = [ordered]@{
        ".github/agents/oh-my-pbi.md"           = ".github/agents/oh-my-pbi.md"
        ".github/agents/pbi-researcher.md"      = ".github/agents/pbi-researcher.md"
        ".github/prompts/start-work.prompt.md"  = ".github/prompts/start-work.prompt.md"
        ".agents/skills/"                        = ".agents/skills/"
        ".vscode/mcp.json"                       = ".vscode/mcp.json"
        "skills-lock.json"                       = "skills-lock.json"
    }

    # ── Helpers ──────────────────────────────────────────────────────────────────
    function Write-Header {
        Write-Host ""
        Write-Host "  ██████╗ ██╗  ██╗      ███╗   ███╗██╗   ██╗    ██████╗ ██████╗ ██╗" -ForegroundColor Magenta
        Write-Host "  ██╔═══██╗██║  ██║      ████╗ ████║╚██╗ ██╔╝    ██╔══██╗██╔══██╗██║" -ForegroundColor Magenta
        Write-Host "  ██║   ██║███████║█████╗██╔████╔██║ ╚████╔╝     ██████╔╝██████╔╝██║" -ForegroundColor Magenta
        Write-Host "  ██║   ██║██╔══██║╚════╝██║╚██╔╝██║  ╚██╔╝      ██╔═══╝ ██╔══██╗██║" -ForegroundColor Magenta
        Write-Host "  ╚██████╔╝██║  ██║      ██║ ╚═╝ ██║   ██║       ██║     ██████╔╝██║" -ForegroundColor Magenta
        Write-Host "   ╚═════╝ ╚═╝  ╚═╝      ╚═╝     ╚═╝   ╚═╝       ╚═╝     ╚═════╝ ╚═╝" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  Installer v1 · github.com/$REPO_OWNER/$REPO_NAME" -ForegroundColor DarkGray
        Write-Host ""
    }

    function Write-Step([string]$Msg) { Write-Host "  ▸ $Msg" -ForegroundColor Cyan }
    function Write-Ok([string]$Msg)   { Write-Host "  ✔ $Msg" -ForegroundColor Green }
    function Write-Warn([string]$Msg) { Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
    function Write-Fail([string]$Msg) { Write-Host "  ✖ $Msg" -ForegroundColor Red }

    # ── Main ─────────────────────────────────────────────────────────────────────
    Write-Header

    try {
        # 1. Validate and resolve target path
        #    Use GetFullPath (not Resolve-Path) to prevent wildcard expansion.
        if ($Path -match '[\*\?\[\]]') {
            throw "'-Path' must not contain wildcard characters."
        }
        $targetPath = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-Path $targetPath -PathType Container)) {
            throw "Path '$targetPath' does not exist or is not a directory."
        }
        Write-Step "Target project : $targetPath"

        if (-not (Test-Path (Join-Path $targetPath '.git'))) {
            Write-Warn "No .git folder found at '$targetPath'. Continuing anyway."
        }

        # 2. Prepare a clean temp directory
        #    Remove any stale remnants from a previous failed run before creating.
        if (Test-Path $TEMP_DIR) {
            Remove-Item -Path $TEMP_DIR -Recurse -Force
        }
        New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null

        # 3. Download ZIP
        $zipFile = Join-Path $TEMP_DIR "source.zip"
        Write-Step "Downloading from GitHub..."
        Invoke-WebRequest -Uri $ZIP_URL -OutFile $zipFile -UseBasicParsing

        # 4. Extract ZIP
        Write-Step "Extracting..."
        Expand-Archive -Path $zipFile -DestinationPath $TEMP_DIR -Force

        # The archive extracts to a folder named <repo>-<branch>
        $extractedRoot = Join-Path $TEMP_DIR "$REPO_NAME-$BRANCH"
        if (-not (Test-Path $extractedRoot)) {
            throw "Unexpected archive structure — expected folder '$REPO_NAME-$BRANCH' inside the ZIP."
        }

        # 5. Build copy list; fail immediately if any manifest entry is missing in the archive
        $copyList  = [System.Collections.Generic.List[hashtable]]::new()
        $conflicts = [System.Collections.Generic.List[string]]::new()
        $missing   = [System.Collections.Generic.List[string]]::new()

        foreach ($entry in $MANIFEST.GetEnumerator()) {
            $srcRel  = $entry.Key   -replace '/', '\'
            $destRel = $entry.Value -replace '/', '\'
            $src     = Join-Path $extractedRoot $srcRel
            $dest    = Join-Path $targetPath    $destRel
            $isDir   = $srcRel.EndsWith('\')

            if (-not (Test-Path $src)) {
                $missing.Add($entry.Key)
                continue
            }

            $copyList.Add(@{ Src = $src; Dest = $dest; IsDir = $isDir; Rel = $entry.Value })

            if (Test-Path $dest) {
                $conflicts.Add($entry.Value)
            }
        }

        if ($missing.Count -gt 0) {
            throw "Downloaded archive is missing required files: $($missing -join ', '). The release may be corrupt or the branch layout has changed."
        }

        # 6. Conflict resolution
        $overwrite = $true
        if ($conflicts.Count -gt 0) {
            Write-Host ""
            Write-Host "  The following already exist in your project and will be replaced:" -ForegroundColor Yellow
            foreach ($c in $conflicts) {
                Write-Host "    • $c" -ForegroundColor DarkYellow
            }
            Write-Host "  (Existing directories are fully replaced, not merged.)" -ForegroundColor DarkGray
            Write-Host ""
            $answer = Read-Host "  Replace/overwrite all? [Y/n]"
            if ($answer -match '^[Nn]') {
                Write-Fail "Installation aborted. No files were changed."
                return
            }
        }

        # 7. Copy files
        Write-Step "Installing files..."
        foreach ($item in $copyList) {
            $destParent = Split-Path $item.Dest -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }

            if ($item.IsDir) {
                # Full replacement: remove the existing directory first so no
                # stale files from a previous installation are left behind.
                if (Test-Path $item.Dest) {
                    Remove-Item -Path $item.Dest -Recurse -Force
                }
                New-Item -ItemType Directory -Path $item.Dest | Out-Null
                Copy-Item -Path (Join-Path $item.Src '*') -Destination $item.Dest -Recurse -Force
            }
            else {
                Copy-Item -Path $item.Src -Destination $item.Dest -Force
            }

            Write-Ok $item.Rel
        }

        # 8. Success message
        Write-Host ""
        Write-Host "  ✅  oh-my-pbi installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor White
        Write-Host "    1. Open this folder in VS Code:  code $targetPath" -ForegroundColor DarkGray
        Write-Host "    2. Accept any MCP server prompts (microsoft-docs, context7)" -ForegroundColor DarkGray
        Write-Host "    3. Open Copilot Chat and type:" -ForegroundColor DarkGray
        Write-Host "         @oh-my-pbi start work on [feature name]" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  Docs: https://github.com/$REPO_OWNER/$REPO_NAME" -ForegroundColor DarkGray
        Write-Host ""
    }
    catch {
        Write-Fail "Installation failed: $_"
    }
    finally {
        if (Test-Path $TEMP_DIR) {
            Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Invoke-OhMyPbiInstall @PSBoundParameters

