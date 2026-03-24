#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# ============================================================
# ccswitch installer
# Overwrites .cmd and .ps1 shims in node_global so that
# codex / claude / gemini / opencode automatically pick up
# the active provider API key + base-url from cc-switch.
# Originals are backed up as <file>.ccswitch-backup
# ============================================================

# ----------------------------------------------------------
# Locate node_global
# ----------------------------------------------------------
$nodeGlobalDir = "D:\Program Files\nodejs\node_global"
foreach ($probe in @("claude","codex","gemini")) {
    $found = Get-Command $probe -ErrorAction SilentlyContinue
    if ($found -and $found.Source -and (Test-Path $found.Source)) {
        $candidate = Split-Path -Parent $found.Source
        if (Test-Path (Join-Path $candidate ($probe + ".cmd"))) {
            $nodeGlobalDir = $candidate
            break
        }
    }
}
Write-Host "node_global dir: $nodeGlobalDir"

$dbPath       = Join-Path $env:USERPROFILE ".cc-switch\cc-switch.db"
$settingsPath = Join-Path $env:USERPROFILE ".cc-switch\settings.json"
$nodeMod      = Join-Path $nodeGlobalDir "node_modules"
$nodeExeAbs   = Join-Path $nodeGlobalDir "node.exe"

$cliJsMap = @{
    'codex'    = Join-Path $nodeMod '@openai\codex\bin\codex.js'
    'claude'   = Join-Path $nodeMod '@anthropic-ai\claude-code\cli.js'
    'gemini'   = Join-Path $nodeMod '@google\gemini-cli\dist\index.js'
    'opencode' = Join-Path $nodeMod 'opencode\dist\index.js'
}

$clis = @("codex", "claude", "gemini", "opencode")

foreach ($cli in $clis) {
    $cmdTarget = Join-Path $nodeGlobalDir ($cli + ".cmd")
    $ps1Target = Join-Path $nodeGlobalDir ($cli + ".ps1")
    $cliJs     = $cliJsMap[$cli]

    if (-not (Test-Path $cmdTarget)) {
        Write-Host "Skipped (not found): $cmdTarget"
        continue
    }

    # Backup originals (only once)
    $cmdBackup = $cmdTarget + ".ccswitch-backup"
    if (-not (Test-Path $cmdBackup)) {
        Copy-Item -Path $cmdTarget -Destination $cmdBackup -Force
        Write-Host "Backed up: $cmdBackup"
    }
    $ps1Backup = $ps1Target + ".ccswitch-backup"
    if ((Test-Path $ps1Target) -and (-not (Test-Path $ps1Backup))) {
        Copy-Item -Path $ps1Target -Destination $ps1Backup -Force
        Write-Host "Backed up: $ps1Backup"
    }

    # Determine node call
    if (Test-Path $cliJs) {
        $nodeExeCmd = if (Test-Path $nodeExeAbs) { '"%~dp0node.exe"' } else { 'node' }
        $nodeCallCmd = "$nodeExeCmd `"$cliJs`" %*"
        $nodeExePs1  = if (Test-Path $nodeExeAbs) { "`"$nodeExeAbs`"" } else { 'node' }
        $nodeCallPs1 = "$nodeExePs1 `"$cliJs`" @args"
    } else {
        $nodeCallCmd = "call `"$cmdBackup`" %*"
        $nodeCallPs1 = "& `"$ps1Backup`" @args"
    }

    # ----------------------------------------------------------
    # Write .cmd wrapper (pure batch, no PowerShell)
    # Uses a helper .py file to avoid quoting hell in batch
    # ----------------------------------------------------------
    $pyHelperPath = Join-Path $nodeGlobalDir "ccswitch-env.py"

    $cmdLines = @()
    $cmdLines += '@echo off'
    $cmdLines += 'setlocal EnableExtensions EnableDelayedExpansion'
    $forLine = 'for /f "usebackq tokens=1,* delims==" %%A in (`python "' + $pyHelperPath + '" "' + $settingsPath + '" ' + $cli + ' "' + $dbPath + '" 2^>nul`) do set "%%A=%%B"'
    $cmdLines += $forLine
    $cmdLines += $nodeCallCmd
    $cmdLines += 'exit /b %ERRORLEVEL%'
    Set-Content -Path $cmdTarget -Value ($cmdLines -join "`r`n") -Encoding ASCII
    Write-Host "Written: $cmdTarget"

    # ----------------------------------------------------------
    # Write .ps1 wrapper
    # ----------------------------------------------------------
    $ps1Lines = @()
    $ps1Lines += '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8'
    $ps1Lines += ('$dbPath       = ' + "'$dbPath'")
    $ps1Lines += ('$settingsPath = ' + "'$settingsPath'")
    $ps1Lines += ('$appType      = ' + "'$cli'")
    $ps1Lines += ('$pyHelper     = ' + "'$pyHelperPath'")
    $ps1Lines += ''
    $ps1Lines += '$py = Get-Command python -ErrorAction SilentlyContinue'
    $ps1Lines += 'if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }'
    $ps1Lines += 'if ($py) {'
    $ps1Lines += '    $out = & $py $pyHelper $settingsPath $appType $dbPath 2>$null'
    $ps1Lines += '    foreach ($line in $out) {'
    $ps1Lines += '        if ($line -match "^([^=]+)=(.*)$") {'
    $ps1Lines += '            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")'
    $ps1Lines += '        }'
    $ps1Lines += '    }'
    $ps1Lines += '}'
    $ps1Lines += $nodeCallPs1
    $ps1Lines += 'exit $LASTEXITCODE'
    Set-Content -Path $ps1Target -Value ($ps1Lines -join "`n") -Encoding UTF8
    Write-Host "Written: $ps1Target"
}

# ----------------------------------------------------------
# Write the shared Python helper script
# ----------------------------------------------------------
$pyHelperPath = Join-Path $nodeGlobalDir "ccswitch-env.py"
$pyContent = @'
import json, sqlite3, sys

settings_path = sys.argv[1]
app_type      = sys.argv[2]
db_path       = sys.argv[3]

try:
    s = json.load(open(settings_path, 'r', encoding='utf-8'))
except Exception:
    s = {}

key = 'currentProvider' + app_type[0].upper() + app_type[1:]
provider_id = s.get(key)

try:
    conn = sqlite3.connect(db_path)
    cur  = conn.cursor()
    if provider_id:
        row = cur.execute(
            'SELECT settings_config FROM providers WHERE id=? AND app_type=?',
            (provider_id, app_type)
        ).fetchone()
    else:
        row = cur.execute(
            'SELECT settings_config FROM providers WHERE app_type=? AND is_current=1 ORDER BY created_at DESC LIMIT 1',
            (app_type,)
        ).fetchone()
    s2 = json.loads(row[0]) if row and row[0] else {}
    actual_pid = provider_id
    if not actual_pid:
        row2 = cur.execute(
            'SELECT id FROM providers WHERE app_type=? AND is_current=1 ORDER BY created_at DESC LIMIT 1',
            (app_type,)
        ).fetchone()
        actual_pid = row2[0] if row2 else None
    ep = cur.execute(
        'SELECT url FROM provider_endpoints WHERE provider_id=? AND app_type=? ORDER BY id LIMIT 1',
        (actual_pid, app_type)
    ).fetchone() if actual_pid else None
except Exception:
    s2 = {}
    ep = None

env2 = {**s2.get('env', {}), **s2.get('auth', {})}
if ep:
    env2['OPENAI_BASE_URL']    = ep[0]
    env2['ANTHROPIC_BASE_URL'] = ep[0]

for k, v in env2.items():
    if v:
        print(str(k) + '=' + str(v))
'@
Set-Content -Path $pyHelperPath -Value $pyContent -Encoding UTF8
Write-Host "Written: $pyHelperPath"

Write-Host ""
Write-Host "ccswitch installed for: $($clis -join ', ')"
Write-Host "Restart your terminal / IDE terminal sessions to activate."
Write-Host "To uninstall, run: uninstall-ccswitch-final.ps1"
