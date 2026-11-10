# ==============================================================================
# Automated PostgreSQL Backup Script for SDMS (Windows / PowerShell)
# ==============================================================================
# Schedules: Run via Windows Task Scheduler daily or weekly
# Usage: powershell -ExecutionPolicy Bypass -File .\backup_db.ps1
# ==============================================================================

param(
    [string]$DbName = "sdms_db",
    [string]$DbUser = "postgres",
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$BackupDir = "D:\student-data-management-system\backend\backups",
    [int]$RetentionDays = 30
)

# 1. Ensure backup directory exists
if (!(Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Host "[INIT] Created backup directory at: $BackupDir" -ForegroundColor Cyan
}

# 2. Generate timestamped filename
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "${DbName}_backup_${Timestamp}.sql"
$ZipFile = "${BackupFile}.gz"
$ChecksumFile = "${BackupFile}.sha256"

# 3. Locate pg_dump
$PgDump = Get-Command "pg_dump.exe" -ErrorAction SilentlyContinue
if (!$PgDump) {
    # Check default PostgreSQL installation paths
    $StandardPaths = @(
        "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\15\bin\pg_dump.exe"
    )
    foreach ($p in $StandardPaths) {
        if (Test-Path $p) {
            $PgDump = $p
            break
        }
    }
}

if (!$PgDump) {
    Write-Host "[ERROR] pg_dump.exe could not be found. Please ensure PostgreSQL bin directory is in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "[BACKUP] Starting PostgreSQL database backup for '$DbName'..." -ForegroundColor Green
$env:PGPASSWORD = if ($env:PGPASSWORD) { $env:PGPASSWORD } else { "root" }

# 4. Execute pg_dump
& $PgDump -h $DbHost -p $DbPort -U $DbUser -F c -b -v -f $BackupFile $DbName 2>&1 | Write-Host

if (Test-Path $BackupFile) {
    $FileSize = (Get-Item $BackupFile).Length / 1MB
    Write-Host ("[SUCCESS] Database backup created: {0} ({1:N2} MB)" -f $BackupFile, $FileSize) -ForegroundColor Green

    # 5. Calculate SHA-256 Checksum for integrity verification
    $Hash = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash
    "$Hash *$([System.IO.Path]::GetFileName($BackupFile))" | Out-File -FilePath $ChecksumFile -Encoding utf8
    Write-Host "[INTEGRITY] SHA-256 Checksum saved: $Hash" -ForegroundColor Cyan

    # 6. Retention Cleanup: Remove backups older than $RetentionDays
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $BackupDir -Filter "${DbName}_backup_*.sql" | Where-Object { $_.LastWriteTime -lt $CutoffDate } | ForEach-Object {
        Remove-Item $_.FullName -Force
        $ChecksumOld = "$($_.FullName).sha256"
        if (Test-Path $ChecksumOld) { Remove-Item $ChecksumOld -Force }
        Write-Host "[RETENTION] Purged expired backup: $($_.Name)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[FAILURE] Database backup failed. Check PostgreSQL service status." -ForegroundColor Red
    exit 1
}
