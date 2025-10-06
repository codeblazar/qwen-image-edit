# Qwen Image Edit API - Key Management
# Stores and rotates the API key with history tracking

$keyFile = "$PSScriptRoot\.api_key"
$historyFile = "$PSScriptRoot\.api_key_history"

function Get-StoredApiKey {
    if (Test-Path $keyFile) {
        return Get-Content $keyFile -Raw
    }
    return $null
}

function Set-StoredApiKey {
    param([string]$key)
    $key | Out-File $keyFile -NoNewline -Encoding UTF8
    Write-Host "API key saved to: $keyFile" -ForegroundColor Green
    
    # Add to history
    Add-KeyToHistory -key $key -action "Generated"
}

function Add-KeyToHistory {
    param(
        [string]$key,
        [string]$action = "Generated"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp | $action | $key"
    Add-Content -Path $historyFile -Value $entry -Encoding UTF8
}

function Show-KeyHistory {
    if (-not (Test-Path $historyFile)) {
        Write-Host "No key history found." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "API Key History:" -ForegroundColor Cyan
    Write-Host "=" * 100 -ForegroundColor Gray
    Write-Host ""
    
    $entries = Get-Content $historyFile
    foreach ($entry in $entries) {
        $parts = $entry -split " \| "
        if ($parts.Count -eq 3) {
            $timestamp = $parts[0]
            $action = $parts[1]
            $key = $parts[2]
            
            $color = "White"
            if ($action -eq "Rotated") { $color = "Yellow" }
            if ($action -eq "Generated") { $color = "Green" }
            
            Write-Host "$timestamp " -NoNewline -ForegroundColor Gray
            Write-Host "[$action] " -NoNewline -ForegroundColor $color
            Write-Host "$key" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "=" * 100 -ForegroundColor Gray
    
    # Show current active key
    $currentKey = Get-StoredApiKey
    if ($currentKey) {
        Write-Host "CURRENT ACTIVE KEY: " -NoNewline -ForegroundColor Green
        Write-Host "$currentKey" -ForegroundColor Yellow
    }
    Write-Host ""
}

function New-ApiKey {
    $key = python -c "import secrets; print(secrets.token_urlsafe(32))"
    Set-StoredApiKey $key
    return $key
}

function Show-ApiKey {
    $key = Get-StoredApiKey
    if ($key) {
        Write-Host ""
        Write-Host "Current API Key:" -ForegroundColor Cyan
        Write-Host $key -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Use this key in requests:" -ForegroundColor Gray
        Write-Host "X-API-Key: $key" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "No API key found. Run with -Generate to create one." -ForegroundColor Yellow
    }
}

function Rotate-ApiKey {
    $oldKey = Get-StoredApiKey
    if ($oldKey) {
        Write-Host "Old key: $oldKey" -ForegroundColor Red
        # Log the old key as rotated
        Add-KeyToHistory -key $oldKey -action "Rotated (replaced)"
    }
    
    $newKey = python -c "import secrets; print(secrets.token_urlsafe(32))"
    $newKey | Out-File $keyFile -NoNewline -Encoding UTF8
    Add-KeyToHistory -key $newKey -action "Rotated (new)"
    
    Write-Host "New key: $newKey" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT: Update all clients with the new key!" -ForegroundColor Yellow
    Write-Host "Restart the API server for the change to take effect." -ForegroundColor Yellow
}

# Main script
param(
    [switch]$Generate,
    [switch]$Show,
    [switch]$Rotate,
    [switch]$History
)

if ($Generate) {
    Write-Host "Generating new API key..." -ForegroundColor Cyan
    $key = New-ApiKey
    Write-Host ""
    Write-Host "API Key: $key" -ForegroundColor Yellow
    Write-Host ""
} elseif ($Rotate) {
    Write-Host "Rotating API key..." -ForegroundColor Cyan
    Rotate-ApiKey
} elseif ($History) {
    Show-KeyHistory
} elseif ($Show) {
    Show-ApiKey
} else {
    # Default: show current key or generate if none exists
    $key = Get-StoredApiKey
    if (-not $key) {
        Write-Host "No API key found. Generating new one..." -ForegroundColor Yellow
        $key = New-ApiKey
    }
    Show-ApiKey
}
