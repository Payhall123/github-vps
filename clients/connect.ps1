# Connect your local machine to the model(s) running in the codespace.
# Usage:  .\clients\connect.ps1                    # forwards 8080 + 8081
#         .\clients\connect.ps1 -Codespace my-cs
#         .\clients\connect.ps1 -Ports 8080        # single port only
# Keep this window open. In another window: curl http://localhost:8080/v1/models
param(
    [string]$Codespace = "",
    [int[]]$Ports = @(8080, 8081)
)

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI not found. Install it:  winget install GitHub.cli"
}

$list = gh codespace list --json name,state 2>$null | ConvertFrom-Json
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

$maps = $Ports | ForEach-Object { "$_`:$_" }
Write-Host ("Forwarding remote -> local: " + ($Ports -join ", ")) -ForegroundColor Cyan
Write-Host "Leave this running. Ctrl+C to disconnect.`n" -ForegroundColor DarkGray

# Blocking: this keeps the tunnels, and the SSH session keeps the box awake.
gh codespace ports forward @maps -c $Codespace
