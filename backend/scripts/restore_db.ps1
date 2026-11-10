# ==============================================================================
# Database Restoration / Disaster Recovery Script for SDMS (Windows / PowerShell)
# ==============================================================================
# Usage: powershell -ExecutionPolicy Bypass -File .\restore_db.ps1 -BackupPath "..\backups\sdms_db_backup_20261017_112000.sql"
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    [string]$DbName = "sdms_db",
    [string]$DbUser = "postgres",
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432"
)

if (!(Test-Path $BackupPath)) {
    Write-Host "[ERROR] Specified backup file does not exist: $BackupPath" -ForegroundColor Red
    exit 1
}

# 1. Verify Checksum if present
$ChecksumFile = "${BackupPath}.sha256"
if (Test-Path $ChecksumFile) {
    Write-Host "[VERIFY] Verifying SHA-256 integrity checksum..." -ForegroundColor Cyan
    $ExpectedHash = (Get-Content $ChecksumFile).Split(" ")[0].Trim()
    $ActualHash = (Get-FileHash -Path $BackupPath -Algorithm SHA256).Hash
    if ($ExpectedHash -ieq $ActualHash) {
        Write-Host "[INTEGRITY PASS] Checksum matched ($ActualHash)" -ForegroundColor Green
    } else {
        Write-Host "[INTEGRITY ERROR] Checksum mismatch! The backup file may be corrupted." -ForegroundColor Red
        exit 1
    }
}

# 2. Locate pg_restore
$PgRestore = Get-Command "pg_restore.exe" -ErrorAction SilentlyContinue
if (!$PgRestore) {
    $StandardPaths = @(
        "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe",
        "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe",
        "C:\Program Files\PostgreSQL\16\bin\pg_restore.exe",
        "C:\Program Files\PostgreSQL\15\bin\pg_restore.exe"
    )
    foreach ($p in $StandardPaths) {
        if (Test-Path $p) {
            $PgRestore = $p
            break
        }
    }
}

if (!$PgRestore) {
    Write-Host "[ERROR] pg_restore.exe could not be found. Please ensure PostgreSQL bin directory is in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "[RESTORE] Restoring database '$DbName' from '$BackupPath'..." -ForegroundColor Yellow
$env:PGPASSWORD = if ($env:PGPASSWORD) { $env:PGPASSWORD } else { "root" }

# 3. Execute pg_restore
& $PgRestore -h $DbHost -p $DbPort -U $DbUser -d $DbName -v --clean --if-exists $BackupPath 2>&1 | Write-Host

Write-Host "[SUCCESS] Database restoration completed." -ForegroundColor Green
