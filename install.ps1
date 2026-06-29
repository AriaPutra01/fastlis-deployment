<#
.SYNOPSIS
LIMS One-Click Installer for Windows

.DESCRIPTION
This script installs and configures the LIMS application on Windows.
It requires Administrator privileges to setup scheduled tasks and modify paths.
#>

param()

# ============================================
# LIMS One-Click Installer (Windows)
# ============================================

Write-Host "🚀 LIMS Installation Started..." -ForegroundColor Cyan

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠️ Please run PowerShell as Administrator to install LIMS." -ForegroundColor Red
    Exit
}

# ============================================
# STEP 1: INTERACTIVE SETUP
# ============================================
Write-Host "`n=== Step 1: Basic Configuration ===" -ForegroundColor Blue

$APP_NAME = Read-Host "Enter App Name [fastlis]"
if ([string]::IsNullOrWhiteSpace($APP_NAME)) { $APP_NAME = "fastlis" }

$INSTALL_PATH = Read-Host "Enter Installation Path [C:\fastlis]"
if ([string]::IsNullOrWhiteSpace($INSTALL_PATH)) { $INSTALL_PATH = "C:\fastlis" }

$GITHUB_TOKEN = Read-Host "Enter GitHub Token (leave empty if repo is public)"

$UPDATE_FREQ = Read-Host "Update frequency (daily/weekly) [daily]"
if ([string]::IsNullOrWhiteSpace($UPDATE_FREQ)) { $UPDATE_FREQ = "daily" }

Write-Host "`nDatabase selected: PostgreSQL & Redis" -ForegroundColor Green

$DB_PASSWORD = Read-Host -AsSecureString "PostgreSQL password"
$DB_PASSWORD_PLAIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DB_PASSWORD))

$REDIS_PASSWORD = Read-Host -AsSecureString "Redis password"
$REDIS_PASSWORD_PLAIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($REDIS_PASSWORD))

# ============================================
# STEP 2: SYSTEM CHECK
# ============================================
Write-Host "`n=== Step 2: System Verification ===" -ForegroundColor Blue

function Check-Command {
    param([string]$CommandName, [string]$InstallTip)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✓ $CommandName installed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️ $CommandName not found. $InstallTip" -ForegroundColor Yellow
        return $false
    }
}

$missingDeps = $false
if (-not (Check-Command "git" "Please install Git from https://git-scm.com/")) { $missingDeps = $true }
if (-not (Check-Command "docker" "Please install Docker Desktop from https://www.docker.com/products/docker-desktop")) { $missingDeps = $true }

if ($missingDeps) {
    Write-Host "`n❌ Please install missing dependencies and restart the installer." -ForegroundColor Red
    Exit
}

# ============================================
# STEP 3: SETUP DIRECTORY & CLONE REPO
# ============================================
Write-Host "`n=== Step 3: Creating Installation Directory ===" -ForegroundColor Blue

if (-not (Test-Path $INSTALL_PATH)) {
    New-Item -ItemType Directory -Force -Path $INSTALL_PATH | Out-Null
}

Set-Location $INSTALL_PATH

if (-not (Test-Path ".git")) {
    Write-Host "Cloning repository..." -ForegroundColor Yellow
    
    if ([string]::IsNullOrWhiteSpace($GITHUB_TOKEN)) {
        git clone https://github.com/AriaPutra01/fastlis-deployment.git .
    } else {
        git clone "https://${GITHUB_TOKEN}@github.com/AriaPutra01/fastlis-deployment.git" .
    }
    
    Write-Host "✓ Repository cloned" -ForegroundColor Green
} else {
    Write-Host "✓ Repository already exists at path" -ForegroundColor Green
}

# ============================================
# STEP 4: CREATE ENVIRONMENT FILE
# ============================================
Write-Host "`n=== Step 4: Creating Configuration ===" -ForegroundColor Blue

# Generate random JWT secret (equivalent to openssl rand -hex 32)
$Bytes = New-Object Byte[] 32
(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($Bytes)
$JWT_SECRET = -join ($Bytes | ForEach-Object { "{0:x2}" -f $_ })

$KeyBytes = New-Object Byte[] 16
(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($KeyBytes)
$INTERNAL_API_KEY = -join ($KeyBytes | ForEach-Object { "{0:x2}" -f $_ })

$EnvContent = @"
# Auto-generated configuration
APP_NAME=$APP_NAME
APP_ENV=production
PORT=8080
ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://frontend:5173

# Database configuration
BLUEPRINT_DB_HOST=psql_bp
BLUEPRINT_DB_PORT=5432
BLUEPRINT_DB_DATABASE=fastlis
BLUEPRINT_DB_USERNAME=postgres
BLUEPRINT_DB_PASSWORD=$DB_PASSWORD_PLAIN
BLUEPRINT_DB_SCHEMA=public
BLUEPRINT_DB_MIGRATION_PATH=file://internal/database/migrations

# Redis configuration
REDIS_HOST=redis_bp
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD_PLAIN

# Security
JWT_SECRET=$JWT_SECRET
JWT_ACCESS_EXPIRY=60
JWT_REFRESH_EXPIRY=7
LOG_LEVEL=4

# Integration & Messaging
RABBITMQ_USER=guest
RABBITMQ_PASS=guest
INTERNAL_API_KEY=$INTERNAL_API_KEY
MIDDLEWARE_URL=
MIDDLEWARE_API_KEY=
"@

Set-Content -Path ".env" -Value $EnvContent -Encoding UTF8
Write-Host "✓ Configuration saved to .env" -ForegroundColor Green

# ============================================
# STEP 5: SETUP AUTO-UPDATES (Windows Task Scheduler)
# ============================================
Write-Host "`n=== Step 5: Configuring Auto-Updates ===" -ForegroundColor Blue

$UpdateScriptPath = Join-Path $INSTALL_PATH "update.ps1"
$UpdateScriptContent = @"
Set-Location '$INSTALL_PATH'
git pull
docker compose pull
docker compose up -d
"@
Set-Content -Path $UpdateScriptPath -Value $UpdateScriptContent -Encoding UTF8

# Create Scheduled Task Action
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$UpdateScriptPath`""

# Create Scheduled Task Trigger based on frequency
if ($UPDATE_FREQ -eq "daily") {
    $Trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
} else {
    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM
}

# Register the task
$TaskName = "LIMS_AutoUpdate_$APP_NAME"
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "Auto-update LIMS application" -User "SYSTEM" -Force | Out-Null

Write-Host "✓ Auto-update configured via Task Scheduler ($TaskName)" -ForegroundColor Green

# ============================================
# STEP 6: FIRST DEPLOYMENT
# ============================================
Write-Host "`n=== Step 6: First Deployment ===" -ForegroundColor Blue

if (-not [string]::IsNullOrWhiteSpace($GITHUB_TOKEN)) {
    Write-Host "Logging in to GitHub Container Registry (GHCR)..." -ForegroundColor Yellow
    
    # Logout dulu untuk clear state lama
    docker logout ghcr.io 2>$null
    
    # Login dengan PAT
    echo $GITHUB_TOKEN | docker login ghcr.io -u AriaPutra01 --password-stdin
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ GHCR login successful" -ForegroundColor Green
        Start-Sleep -Seconds 3  # Tunggu daemon register credentials
    } else {
        Write-Host "⚠️ GHCR login failed, continuing anyway..." -ForegroundColor Yellow
    }
}

Write-Host "Pulling Docker images..." -ForegroundColor Yellow
docker compose pull

Write-Host "Starting application..." -ForegroundColor Yellow
docker compose up -d

Write-Host "Waiting for application startup (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

$runningContainers = docker compose ps | Select-String -Pattern "Up|running"
if ($runningContainers) {
    Write-Host "✓ Application running!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Check logs: docker compose logs" -ForegroundColor Red
}

# ============================================
# STEP 7: POST-INSTALL
# ============================================
Write-Host "`n=== Step 7: Post-Installation Setup ===" -ForegroundColor Blue

Write-Host "✓ Installation Complete!`n" -ForegroundColor Green
Write-Host "📋 Quick Links:"
Write-Host "  Frontend: http://localhost:5173"
Write-Host "  Backend API: http://localhost:8080"
Write-Host "  Logs: docker compose logs -f"
Write-Host "  View status: docker compose ps"
Write-Host ""
Write-Host "📚 Next Steps:"
Write-Host "  1. Access dashboard and complete initial setup"
Write-Host "  2. Configure database backups"
Write-Host "  3. Test updates by running: .\update.ps1"
