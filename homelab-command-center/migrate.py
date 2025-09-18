#!/usr/bin/env python3
"""
Migration script using yoyo-migrations for HomeLab Command Center
This provides a simple interface to yoyo-migrations for SQL-based migrations.
"""

import os
import sys
import subprocess
from pathlib import Path

def run_yoyo_command(args):
    """Run yoyo-migrations command with proper configuration."""
    migrations_dir = Path(__file__).parent / "migrations"
    sql_dir = migrations_dir / "sql"
    
    # Database URL from environment or default
    db_url = os.getenv("DATABASE_URL", "postgresql://homelab_user:homelab_password@localhost:5432/homelab_command_center")
    
    # Build yoyo command
    cmd = [
        "yoyo-migrations",
        "--database", db_url,
        "--migrations-table", "yoyo_migrations",
        "migrate", str(sql_dir)
    ] + args
    
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=Path(__file__).parent)

def main():
    """Main CLI interface."""
    if len(sys.argv) < 2:
        print("Yoyo Migrations for HomeLab Command Center")
        print("\nUsage: python migrate.py <command> [options]")
        print("\nCommands:")
        print("  apply                        - Apply all pending migrations")
        print("  rollback                     - Rollback last migration")
        print("  rollback-to <version>        - Rollback to specific version")
        print("  status                       - Show migration status")
        print("  list                         - List all migrations")
        print("  mark <version>               - Mark migration as applied without running")
        print("  help                         - Show this help message")
        print("\nEnvironment Variables:")
        print("  DATABASE_URL                 - Database connection string")
        return
    
    command = sys.argv[1]
    
    try:
        if command == "apply":
            result = run_yoyo_command([])
            sys.exit(result.returncode)
        
        elif command == "rollback":
            result = run_yoyo_command(["--rollback"])
            sys.exit(result.returncode)
        
        elif command == "rollback-to":
            if len(sys.argv) < 3:
                print("Error: Version required for rollback-to")
                sys.exit(1)
            version = sys.argv[2]
            result = run_yoyo_command(["--rollback", "--revision", version])
            sys.exit(result.returncode)
        
        elif command == "status":
            result = run_yoyo_command(["--status"])
            sys.exit(result.returncode)
        
        elif command == "list":
            result = run_yoyo_command(["--list"])
            sys.exit(result.returncode)
        
        elif command == "mark":
            if len(sys.argv) < 3:
                print("Error: Version required for mark")
                sys.exit(1)
            version = sys.argv[2]
            result = run_yoyo_command(["--mark", version])
            sys.exit(result.returncode)
        
        elif command == "help":
            print("Yoyo Migrations for HomeLab Command Center")
            print("SQL-based migrations using yoyo-migrations")
        
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
    
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()