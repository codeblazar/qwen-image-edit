# API Key Management Script
# Usage: 
#   .\manage-api-key.ps1 -Action Get
#   .\manage-api-key.ps1 -Action Generate
#   .\manage-api-key.ps1 -Action History

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Get", "Generate", "History")]
    [string]$Action
)

$ApiKeyFile = "$PSScriptRoot\.api_key"
$HistoryFile = "$PSScriptRoot\.api_key_history"

function Get-CurrentApiKey {
    if (Test-Path $ApiKeyFile) {
        $key = Get-Content $ApiKeyFile -Raw
        Write-Host "Current API Key:" -ForegroundColor Cyan
        Write-Host $key.Trim()
        return $key.Trim()
    } else {
        Write-Host "No API key found. Generate one with: .\manage-api-key.ps1 -Action Generate" -ForegroundColor Yellow
        return $null
    }
}

function New-ApiKey {
    # Generate a secure random key (32 bytes, base64url encoded = 43 chars)
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $key = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
    
    Write-Host "`nGenerated New API Key:" -ForegroundColor Green
    Write-Host $key
    
    # Save to .api_key file
    $key | Out-File -FilePath $ApiKeyFile -Encoding utf8 -NoNewline
    Write-Host "`nSaved to: $ApiKeyFile" -ForegroundColor Green
    
    # Append to history
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp | Generated | $key" | Out-File -FilePath $HistoryFile -Append -Encoding utf8
    Write-Host "Added to history: $HistoryFile" -ForegroundColor Green
    
    Write-Host "`nTo use this key:" -ForegroundColor Cyan
    Write-Host "  1. Restart the API server (if running)" -ForegroundColor White
    Write-Host "  2. Include in requests: X-API-Key: $key" -ForegroundColor White
    
    return $key
}

function Get-KeyHistory {
    if (Test-Path $HistoryFile) {
        Write-Host "API Key History:" -ForegroundColor Cyan
        Get-Content $HistoryFile | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "No key history found." -ForegroundColor Yellow
    }
}

# Execute the requested action
switch ($Action) {
    "Get" { Get-CurrentApiKey }
    "Generate" { New-ApiKey }
    "History" { Get-KeyHistory }
}
