<#
.SYNOPSIS
RunMaintenance.ps1
Runs DISM and SFC, reports results to Power Automate.

This script reads config from:
  C:\ProgramData\Maintenance\config.json

Config.json format example:
{
  "flowUri": "https://prod-xxx.logic.azure.com/...",
  "apiKey": "VerySecretKey123!"
}

No secrets in this script. Logs are deleted after running.
#>

# --- Settings ---
$InstallDir = "C:\ProgramData\Maintenance"
$configPath = Join-Path $InstallDir 'config.json'
$logPath    = Join-Path $InstallDir 'RunMaintenance.log'
$errPattern = '(?i)error|failed|cannot repair|corrupt|unable|failure'

function Log {
    param([string]$message)
    $timestamp = (Get-Date).ToString("o")
    $entry = "$timestamp - $message"
    Add-Content -Path $logPath -Value $entry
    Write-Output $message
}

# --- Load config ---
if (-not (Test-Path $configPath)) {
    Write-Error "Missing config.json at $configPath. Aborting."
    exit 2
}

try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config.json: $($_.Exception.Message)"
    exit 2
}

if (-not $config.flowUri -or -not $config.apiKey) {
    Write-Error "config.json missing required fields 'flowUri' and/or 'apiKey'. Aborting."
    exit 2
}

$flowUri = $config.flowUri
$apiKey  = $config.apiKey

# --- Helper: Extract last N error lines from text ---
function Get-LastErrorsFromText {
    param(
        [Parameter(Mandatory=$true)][Object]$textOrLines,
        [int]$max = 5
    )
    $matches = @()
    try {
        $lines = @()
        if ($textOrLines -is [string]) { $lines = $textOrLines -split "`r?`n" }
        else { $lines = $textOrLines }
        $matches = ($lines | Select-String -Pattern $errPattern -AllMatches | ForEach-Object { $_.Line }) | Select-Object -Unique
        return @($matches | Select-Object -Last $max)
    } catch {
        return @()
    }
}

# --- Run DISM ---
Log "Starting DISM /Online /Cleanup-Image /RestoreHealth ..."
$dismOutput = & dism.ex
