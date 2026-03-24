#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# ============================================================
# ccswitch uninstaller
# Restores original .cmd/.ps1 files in node_global from backups
# and removes the shared Python helper.
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
    # Also probe via backup files
    foreach ($ext in @(".cmd", ".ps1")) {
        $bp = Join-Path $nodeGlobalDir ($probe + $ext + ".ccswitch-backup")
        if (Test-Path $bp) { break }
    }
}
Write-Host "node_global dir: $nodeGlobalDir"

$clis = @("codex", "claude", "gemini", "opencode")

foreach ($cli in $clis) {
    foreach ($ext in @(".cmd", ".ps1")) {
        $target = Join-Path $nodeGlobalDir ($cli + $ext)
        $backup = $target + ".ccswitch-backup"
        if (Test-Path $backup) {
            Copy-Item -Path $backup -Destination $target -Force
            Remove-Item -Path $backup -Force
            Write-Host "Restored: $target"
        }
    }
}

# Remove the shared Python helper
$pyHelper = Join-Path $nodeGlobalDir "ccswitch-env.py"
if (Test-Path $pyHelper) {
    Remove-Item -Path $pyHelper -Force
    Write-Host "Removed: $pyHelper"
}

# Remove temp codex config if it exists
$tempCodex = Join-Path $env:TEMP "ccswitch-codex"
if (Test-Path $tempCodex) {
    Remove-Item -Path $tempCodex -Recurse -Force
    Write-Host "Removed: $tempCodex"
}

Write-Host ""
Write-Host "ccswitch uninstalled. Restart your terminals to apply."
