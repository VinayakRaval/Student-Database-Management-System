#!/usr/bin/env python
"""
Cross-Platform PostgreSQL Database Backup Script for SDMS
Features:
- Reads database credentials from environment variables / Django settings
- Dumps database using pg_dump with custom compressed archive format
- Generates SHA-256 integrity checksum
- Automatic retention policy cleanup (defaults to 30 days)
"""

import os
import sys
import subprocess
import hashlib
import shutil
from datetime import datetime, timedelta
from pathlib import Path

# Base Paths
BASE_DIR = Path(__file__).resolve().parent.parent
BACKUP_DIR = BASE_DIR / "backups"
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

# Database Configuration
DB_NAME = os.getenv("DB_NAME", "sdms_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "root")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", 30))

def get_pg_dump_path():
    candidate_paths = [
        "pg_dump",
        r"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe",
        r"C:\Program Files\PostgreSQL\17\bin\pg_dump.exe",
        r"C:\Program Files\PostgreSQL\16\bin\pg_dump.exe",
        r"C:\Program Files\PostgreSQL\15\bin\pg_dump.exe",
    ]
    for p in candidate_paths:
        if Path(p).exists() or shutil.which(p):
            return p
    return "pg_dump"

def run_backup():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"{DB_NAME}_backup_{timestamp}.dump"
    backup_path = BACKUP_DIR / backup_filename
    checksum_path = BACKUP_DIR / f"{backup_filename}.sha256"

    pg_dump_bin = get_pg_dump_path()
    print(f"[*] Starting backup of database '{DB_NAME}' using {pg_dump_bin} to {backup_path}...")

    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASSWORD

    cmd = [
        pg_dump_bin,
        "-h", DB_HOST,
        "-p", DB_PORT,
        "-U", DB_USER,
        "-F", "c",
        "-b",
        "-v",
        "-f", str(backup_path),
        DB_NAME,
    ]

    try:
        result = subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
        size_mb = backup_path.stat().st_size / (1024 * 1024)
        print(f"[+] Backup successfully completed: {backup_filename} ({size_mb:.2f} MB)")

        # Compute SHA-256
        sha256 = hashlib.sha256()
        with open(backup_path, "rb") as f:
            for block in iter(lambda: f.read(65536), b""):
                sha256.update(block)
        checksum = sha256.hexdigest()
        checksum_path.write_text(f"{checksum} *{backup_filename}\n")
        print(f"[+] SHA-256 Checksum: {checksum}")

        # Retention Cleanup
        cutoff = datetime.now() - timedelta(days=RETENTION_DAYS)
        for dump_file in BACKUP_DIR.glob(f"{DB_NAME}_backup_*.dump"):
            file_mtime = datetime.fromtimestamp(dump_file.stat().st_mtime)
            if file_mtime < cutoff:
                dump_file.unlink(missing_ok=True)
                chk = dump_file.with_name(f"{dump_file.name}.sha256")
                chk.unlink(missing_ok=True)
                print(f"[-] Removed expired backup: {dump_file.name}")

    except FileNotFoundError:
        print("[!] Error: 'pg_dump' utility not found. Please ensure PostgreSQL bin directory is in system PATH.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"[!] Backup failed: {e.stderr}")
        sys.exit(1)

if __name__ == "__main__":
    run_backup()
