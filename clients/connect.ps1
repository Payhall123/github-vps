# Connect your local machine to the model in the codespace.
# Usage:  .\clients\connect.ps1                    # first codespace, port 8080
#         .\clients\connect.ps1 -Codespace my-cs   # explicit
# Keep this window open. In another window: curl http://localhost:8080/v1/models
param(
    [string]$Codespace = "",
    [int]$Port = 8080
)

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI not found. Install it:  winget install GitHub.cli"
}

$list = gh codespace list --json name,state,repository 2>$null | ConvertFrom-Json
if (-not $list) { Fail "No codespaces on this account. Create one at https://github.com/codespaces" }

if (-not $Codespace) {
    $Codespace = ($list | Select-Object -First 1).name
    Write-Host "Using codespace: $Codespace" -ForegroundColor Cyan
}

$state = ($list | Where-Object { $_.name -eq $Codespace }).state
if ($state -ne "Available") {
    Write-Host "Codespace is '$state' -- starting it..." -ForegroundColor Yellow
    gh codespace start -c $Codespace
}

Write-Host "Forwarding remote :$Port -> local :$Port" -ForegroundColor Cyan
Write-Host "Leave this running. Ctrl+C to disconnect.`n" -ForegroundColor DarkGray

# Blocking: this keeps the tunnel, and the SSH session keeps the box awake.
gh codespace ports forward "$Port`:$Port" -c $Codespace
