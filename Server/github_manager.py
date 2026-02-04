#!/usr/bin/env python3
"""
Nforst GitHub Manager
- Push: Update URLs to production and push to repo
- Backup: Create local backup before pushing
"""

import os
import re
import shutil
import subprocess
from datetime import datetime

# Configuration
GITHUB_USER = "nonce-ns"
GITHUB_REPO = "Nforst"
GITHUB_BRANCH = "main"
# URL used when pushing to GitHub (raw.githubusercontent.com)
PRODUCTION_BASE = "https://raw.githubusercontent.com/nonce-ns/Nforst/main/"
LOCAL_BASE = "http://192.168.1.8:8000/"

# Set Project Root (Up one level from Server/)
# __file__ = Server/github_manager.py
# dirname = Server
# dirname(dirname) = ProjectRoot
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(PROJECT_DIR, "backups")

# Files to exclude from push (will be removed before push, restored after)
EXCLUDE_FILES = [
    "logs",
    "backups",
    "__pycache__",
    ".git",
]

# Files that need URL replacement
# main.lua uses CONFIG table with BASE_URL and WINDUI_URL
URL_REPLACEMENTS = [
    {
        "file": "main.lua",
        "pattern": r'BASE_URL = "http://[^"]*"',
        "local": f'BASE_URL = "{LOCAL_BASE}"',
        "github": f'BASE_URL = "{PRODUCTION_BASE}"',
    },
    {
        "file": "main.lua",
        "pattern": r'WINDUI_URL = "http://[^"]*"',
        "local": f'WINDUI_URL = "{LOCAL_BASE}WindUI/dist/main.lua"',
        "github": f'WINDUI_URL = "{PRODUCTION_BASE}WindUI/dist/main.lua"',
    },
]


# ANSI Colors
class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"


def print_header():
    print(f"""
{Colors.CYAN}╔══════════════════════════════════════════════════╗
║          Nforst GitHub Manager v1.0              ║
║       github.com/{GITHUB_USER}/{GITHUB_REPO}                 ║
╚══════════════════════════════════════════════════╝{Colors.RESET}
""")


def print_menu():
    print(f"""
{Colors.BOLD}Choose an option:{Colors.RESET}
  {Colors.GREEN}[1]{Colors.RESET} Push to GitHub  - Update URLs & push to repo
  {Colors.YELLOW}[2]{Colors.RESET} Backup          - Create local backup
  {Colors.BLUE}[3]{Colors.RESET} Restore Local   - Revert URLs to local server
  {Colors.RED}[0]{Colors.RESET} Exit
""")


def run_cmd(cmd, cwd=None):
    """Run a shell command and return output"""
    result = subprocess.run(
        cmd, shell=True, cwd=cwd or PROJECT_DIR, capture_output=True, text=True
    )
    return result.returncode == 0, result.stdout, result.stderr


def replace_urls(to_github=True):
    """Replace URLs in files (to GitHub or back to local)"""
    print(f"\n{Colors.CYAN}[*] Updating URLs...{Colors.RESET}")

    for item in URL_REPLACEMENTS:
        filepath = os.path.join(PROJECT_DIR, item["file"])
        if not os.path.exists(filepath):
            print(f"  {Colors.YELLOW}[!] Skip: {item['file']} not found{Colors.RESET}")
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        if to_github:
            new_content = re.sub(
                item["pattern"], item["github"].replace("\\", "\\\\"), content
            )
        else:
            new_content = re.sub(
                item["pattern"], item["local"].replace("\\", "\\\\"), content
            )

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)

        mode = "GitHub" if to_github else "Local"
        print(f"  {Colors.GREEN}[✓]{Colors.RESET} {item['file']} → {mode}")


def create_backup():
    """Create a timestamped backup as .zip file"""
    import zipfile

    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"backup_{timestamp}.zip"
    backup_path = os.path.join(BACKUP_DIR, backup_name)

    print(f"\n{Colors.CYAN}[*] Creating backup: {backup_name}{Colors.RESET}")

    # Create zip file
    with zipfile.ZipFile(backup_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        for item in os.listdir(PROJECT_DIR):
            if item in EXCLUDE_FILES or item.startswith("."):
                continue

            src = os.path.join(PROJECT_DIR, item)

            if os.path.isdir(src):
                # Add directory recursively
                for root, dirs, files in os.walk(src):
                    # Skip excluded directories
                    dirs[:] = [
                        d
                        for d in dirs
                        if d not in EXCLUDE_FILES and not d.startswith(".")
                    ]

                    for file in files:
                        file_path = os.path.join(root, file)
                        arc_name = os.path.relpath(file_path, PROJECT_DIR)
                        zipf.write(file_path, arc_name)
            else:
                zipf.write(src, item)

    # Get file size
    size_kb = os.path.getsize(backup_path) / 1024
    print(
        f"  {Colors.GREEN}[✓]{Colors.RESET} Backup saved: {backup_name} ({size_kb:.1f} KB)"
    )
    return backup_path


def push_to_github():
    """Update URLs and push to GitHub"""
    print(f"\n{Colors.BOLD}=== Push to GitHub ==={Colors.RESET}")

    # Step 1: Create backup first
    print(f"\n{Colors.CYAN}[1/4] Creating backup...{Colors.RESET}")
    create_backup()

    # Step 2: Replace URLs to GitHub
    print(f"\n{Colors.CYAN}[2/4] Updating URLs to GitHub...{Colors.RESET}")
    replace_urls(to_github=True)

    # Step 3: Git operations
    print(f"\n{Colors.CYAN}[3/4] Git operations...{Colors.RESET}")

    # Check if git repo exists
    if not os.path.exists(os.path.join(PROJECT_DIR, ".git")):
        print(f"  {Colors.YELLOW}[!] Initializing git repo...{Colors.RESET}")
        run_cmd("git init")
        run_cmd(f"git remote add origin git@github.com:{GITHUB_USER}/{GITHUB_REPO}.git")

    # Create .gitignore if not exists
    gitignore_path = os.path.join(PROJECT_DIR, ".gitignore")
    if not os.path.exists(gitignore_path):
        with open(gitignore_path, "w") as f:
            f.write("\n".join(EXCLUDE_FILES) + "\n")
        print(f"  {Colors.GREEN}[✓]{Colors.RESET} Created .gitignore")

    # Git add, commit, push
    run_cmd("git add -A")

    commit_msg = f"Update {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    success, out, err = run_cmd(f'git commit -m "{commit_msg}"')

    if "nothing to commit" in (out + err):
        print(f"  {Colors.YELLOW}[!] No changes to commit{Colors.RESET}")
    else:
        print(f"  {Colors.GREEN}[✓]{Colors.RESET} Committed: {commit_msg}")

    print(f"\n{Colors.CYAN}[4/4] Pushing to GitHub...{Colors.RESET}")
    success, out, err = run_cmd(f"git push -u origin {GITHUB_BRANCH} --force")

    if success or "Everything up-to-date" in (out + err):
        print(
            f"  {Colors.GREEN}[✓]{Colors.RESET} Pushed to github.com/{GITHUB_USER}/{GITHUB_REPO}"
        )
    else:
        print(f"  {Colors.RED}[✗] Push failed: {err}{Colors.RESET}")
        print(
            f"  {Colors.YELLOW}[!] Try: git push -u origin {GITHUB_BRANCH} --force{Colors.RESET}"
        )

    # Step 4: Restore URLs to local
    print(f"\n{Colors.CYAN}[*] Restoring local URLs...{Colors.RESET}")
    replace_urls(to_github=False)

    print(f"\n{Colors.GREEN}{'=' * 50}")
    print(f"  Push complete!")
    print(f"  Raw URL: {PRODUCTION_BASE}main.lua")
    print(f"{'=' * 50}{Colors.RESET}")


def restore_local():
    """Restore URLs to local server"""
    print(f"\n{Colors.BOLD}=== Restore to Local ==={Colors.RESET}")
    replace_urls(to_github=False)
    print(f"\n{Colors.GREEN}[✓] URLs restored to local server{Colors.RESET}")


def list_backups():
    """List available backups"""
    if not os.path.exists(BACKUP_DIR):
        print(f"  {Colors.YELLOW}[!] No backups found{Colors.RESET}")
        return []

    backups = sorted(os.listdir(BACKUP_DIR), reverse=True)
    if not backups:
        print(f"  {Colors.YELLOW}[!] No backups found{Colors.RESET}")
        return []

    print(f"\n{Colors.CYAN}Available backups:{Colors.RESET}")
    for i, b in enumerate(backups[:10], 1):
        print(f"  [{i}] {b}")

    return backups


def main():
    print_header()

    while True:
        print_menu()
        choice = input(f"{Colors.BOLD}Enter choice: {Colors.RESET}").strip()

        if choice == "1":
            confirm = input(
                f"\n{Colors.YELLOW}Push to GitHub? This will update all URLs. (y/n): {Colors.RESET}"
            )
            if confirm.lower() == "y":
                push_to_github()
        elif choice == "2":
            create_backup()
            list_backups()
        elif choice == "3":
            restore_local()
        elif choice == "0":
            print(f"\n{Colors.CYAN}Goodbye!{Colors.RESET}\n")
            break
        else:
            print(f"{Colors.RED}Invalid choice{Colors.RESET}")


if __name__ == "__main__":
    main()
