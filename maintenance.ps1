# RunMaintenance.ps1
# This is the hosted version that gets downloaded from GitHub

# ===== CONFIG =====
$flowUri = "https://prod-xxx.logic.azure.com:443/workflows/..."   # Power Automate HTTP endpoint
$apiKey  = "VerySecretKey123!"                                   # Shared secret header
# ==================

# Run elevated check (not needed if run as SYSTEM via scheduled task)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "This script requires administrator rights."
    exit 1
}

Write-Output "Starting DISM..."
$dismOutput = & dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1
$dismExit   = $LASTEXITCODE

Write-Output "Starting SFC..."
$sfcOutput  = & sfc.exe /scannow 2>&1
$sfcExit    = $LASTEXITCODE

# Error pattern
$errPattern = '(?i)error|failed|cannot repair|corrupt|unable|failure'

function Get-LastErrorsFromText {
    param($textOrLines)
    ($textOrLines | Select-String -Pattern $errPattern -AllMatches |
        ForEach-Object { $_.Line }) | Select-Object -Unique -Last 5
}

# Gather DISM errors
$dismErrors = Get-LastErrorsFromText $dismOutput
if (-not $dismErrors) {
    $dismLog = "$env:windir\Logs\DISM\dism.log"
    if (Test-Path $dismLog) {
        $dismErrors = Get-LastErrorsFromText (Get-Content $dismLog -Tail 2000)
    }
}
if (-not $dismErrors) { $dismErrors = @() }

# Gather SFC errors
$sfcErrors = Get-LastErrorsFromText $sfcOutput
if (-not $sfcErrors) {
    $cbsLog = "$env:windir\Logs\CBS\CBS.log"
    if (Test-Path $cbsLog) {
        $sfcErrors = Get-LastErrorsFromText (Get-Content $cbsLog -Tail 2000)
    }
}
if (-not $sfcErrors) { $sfcErrors = @() }

# Summaries
$dismSummary = if (($dismExit -eq 0) -and (-not $dismErrors)) { 'Success' } else { 'Failure' }
$sfcSummary  = if (($sfcExit -eq 0) -and (-not $sfcErrors)) { 'Success' } else { 'Failure' }

# Payload
$payload = @{
    computerName = $env:COMPUTERNAME
    timestamp    = (Get-Date).ToUniversalTime().ToString("o")
    dism = @{
        exitCode = [int]$dismExit
        summary  = $dismSummary
        errors   = $dismErrors
    }
    sfc = @{
        exitCode = [int]$sfcExit
        summary  = $sfcSummary
        errors   = $sfcErrors
    }
}

$body = $payload | ConvertTo-Json -Depth 6

# Post to Power Automate
try {
    $headers = @{ 'x-api-key' = $apiKey }
    Invoke-RestMethod -Uri $flowUri -Method Post -Headers $headers -Body $body -ContentType 'application/json'
    Write-Output "Report sent successfully."
} catch {
    Write-Warning "Failed to send report: $($_.Exception.Message)"
}
