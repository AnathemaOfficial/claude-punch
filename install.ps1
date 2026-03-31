# Claude Punch — Windows Installer
# Installs the punch skill and auto-punch hook for Claude Code

$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$TimelogDir = Join-Path $ClaudeDir "timelog"
$SkillDir = Join-Path $ClaudeDir "skills\punch"
$HooksDir = Join-Path $ClaudeDir "hooks"
$Settings = Join-Path $ClaudeDir "settings.json"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing Claude Punch..." -ForegroundColor Cyan

# Create directories
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
New-Item -ItemType Directory -Force -Path $TimelogDir | Out-Null
New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null

# Copy skill
Copy-Item "$ScriptDir\skills\punch\SKILL.md" "$SkillDir\SKILL.md" -Force
Write-Host "  Skill installed to $SkillDir\" -ForegroundColor Green

# Copy hook
Copy-Item "$ScriptDir\hooks\autopunch.mjs" "$HooksDir\autopunch.mjs" -Force
Write-Host "  Hook installed to $HooksDir\" -ForegroundColor Green

# Create default config
$ConfigPath = Join-Path $TimelogDir "autopunch.json"
if (-not (Test-Path $ConfigPath)) {
    @{
        enabled = $true
        idleMinutes = 5
        autoBackOnPrompt = $true
        autoAwayOnIdle = $true
    } | ConvertTo-Json | Set-Content $ConfigPath
    Write-Host "  Config created at $ConfigPath" -ForegroundColor Green
} else {
    Write-Host "  Config already exists, skipping" -ForegroundColor Yellow
}

# Create example locations
$LocationsPath = Join-Path $TimelogDir "locations.json"
if (-not (Test-Path $LocationsPath)) {
    $hostname = hostname
    @{ $hostname = "My Workstation" } | ConvertTo-Json | Set-Content $LocationsPath
    Write-Host "  Locations created at $LocationsPath (edit to customize)" -ForegroundColor Green
} else {
    Write-Host "  Locations already exists, skipping" -ForegroundColor Yellow
}

# Add hook to settings.json
if (Test-Path $Settings) {
    $content = Get-Content $Settings -Raw
    if ($content -match "autopunch") {
        Write-Host "  Hook already registered in settings.json, skipping" -ForegroundColor Yellow
    } else {
        $hookPath = Join-Path $HooksDir "autopunch.mjs"
        $hookPathForward = $hookPath -replace '\\', '/'
        $nodeCmd = @"
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('$($Settings -replace '\\', '/')', 'utf8'));
if (!settings.hooks) settings.hooks = {};
if (!settings.hooks.PreToolUse) settings.hooks.PreToolUse = [];
settings.hooks.PreToolUse.unshift({
    matcher: '*',
    hooks: [{ type: 'command', command: 'node "$hookPathForward"', timeout: 5 }]
});
fs.writeFileSync('$($Settings -replace '\\', '/')', JSON.stringify(settings, null, 2));
"@
        node -e $nodeCmd
        Write-Host "  Hook registered in settings.json" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: $Settings not found." -ForegroundColor Red
}

Write-Host ""
Write-Host "Done! Restart Claude Code to activate." -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage:" -ForegroundColor White
Write-Host "  /punch in        Start your work session"
Write-Host "  /punch out       End your work session"
Write-Host "  /punch status    Check current status"
Write-Host "  /punch report    Weekly report"
Write-Host ""
Write-Host "Auto-punch detects idle time (>5min) and logs AWAY/BACK automatically."
Write-Host "Edit $LocationsPath to customize location names."
