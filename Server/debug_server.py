#!/usr/bin/env python3
"""
WindUI Remote Log Server v2.1
Receives logs from Roblox client and displays them in terminal
+ Auto IP update for lua files
"""

import http.server
import socketserver
import json
import os
import re
import socket
from datetime import datetime
from urllib.parse import parse_qs, urlparse
import sys

# Force UTF-8 output for Windows
sys.stdout.reconfigure(encoding="utf-8")

# Configuration
PORT = 8000
LOGS_FOLDER = "logs"
SERVE_FILES = True  # Also serve lua files

# Files that need IP update
LUA_FILES_TO_UPDATE = [
    "DevLoader.lua",
    "main.lua",
    "WindUI/dist/main.lua",
    "Src/UI/MainInterface.lua",
    "Libs/Logger.lua",
]

# Python files that also need IP update
PY_FILES_TO_UPDATE = []


# ANSI Colors
class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    GREEN = "\033[92m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GRAY = "\033[90m"


# Current session
session_file = None
log_count = 0


def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "localhost"


def update_ip_in_files(new_ip):
    """Update IP address in all lua files and github_manager.py"""
    # Base dir relative to Project Root (since we change cwd in start_server)
    # But this function might be called before start_server or independently.
    # To be safe, we should use the initial execution path or absolute path.
    # We will assume this is run from the directory where start_server sets us (Project Root)

    # However, if run from menu (option 2), start_server hasn't run yet.
    # Let's verify where we are.

    script_dir = os.path.dirname(os.path.abspath(__file__))  # Server/
    project_root = os.path.dirname(script_dir)  # Project Root

    new_base_url = f"http://{new_ip}:{PORT}/"

    # Pattern to match any local IP base URL in lua files
    lua_pattern = r"http://[\d\.]+:\d+/"

    # Pattern to match LOCAL_BASE in github_manager.py
    py_pattern = r'LOCAL_BASE = "http://[\d\.]+:\d+/"'
    py_replacement = f'LOCAL_BASE = "{new_base_url}"'

    updated_files = []

    # Update Lua files
    for lua_file in LUA_FILES_TO_UPDATE:
        filepath = os.path.join(project_root, lua_file)
        if not os.path.exists(filepath):
            print(f"  {Colors.YELLOW}[!] Skip: {lua_file} not found{Colors.RESET}")
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        # Check if file contains any IP to update
        if re.search(lua_pattern, content):
            new_content = re.sub(lua_pattern, new_base_url, content)

            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)
                updated_files.append(lua_file)
                print(f"  {Colors.GREEN}[✓]{Colors.RESET} {lua_file}")
            else:
                print(
                    f"  {Colors.GRAY}[=]{Colors.RESET} {lua_file} (already up to date)"
                )
        else:
            print(f"  {Colors.GRAY}[-]{Colors.RESET} {lua_file} (no IP found)")

    # Update Python files (github_manager.py)
    for py_file in PY_FILES_TO_UPDATE:
        filepath = os.path.join(project_root, py_file)
        if not os.path.exists(filepath):
            print(f"  {Colors.YELLOW}[!] Skip: {py_file} not found{Colors.RESET}")
            continue

        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        # Check if file contains LOCAL_BASE to update
        if re.search(py_pattern, content):
            new_content = re.sub(py_pattern, py_replacement, content)

            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)
                updated_files.append(py_file)
                print(f"  {Colors.GREEN}[✓]{Colors.RESET} {py_file} (LOCAL_BASE)")
            else:
                print(
                    f"  {Colors.GRAY}[=]{Colors.RESET} {py_file} (already up to date)"
                )
        else:
            print(f"  {Colors.GRAY}[-]{Colors.RESET} {py_file} (no LOCAL_BASE found)")

    return updated_files


def show_menu():
    """Show main menu and return choice"""
    print(f"""
{Colors.BOLD}Menu:{Colors.RESET}
  {Colors.GREEN}[1]{Colors.RESET} Start Server
  {Colors.YELLOW}[2]{Colors.RESET} Update IP in all files
  {Colors.RED}[0]{Colors.RESET} Exit
""")
    return input(f"{Colors.BOLD}Choice: {Colors.RESET}").strip()


def get_level_color(level):
    level = level.lower() if level else "info"
    if level == "error":
        return Colors.RED
    elif level == "warning":
        return Colors.YELLOW
    else:
        return Colors.GRAY


def log_to_terminal(data):
    global log_count
    log_count += 1

    level = data.get("level", "Info")
    message = data.get("message", "")
    time = data.get("time", datetime.now().strftime("%H:%M:%S"))
    username = data.get("username", "Unknown")

    color = get_level_color(level)

    print(
        f"{Colors.CYAN}[{time}]{Colors.RESET} "
        f"{Colors.BLUE}@{username}{Colors.RESET} "
        f"{color}[{level}]{Colors.RESET} "
        f"{message}"
    )


def handle_session_upload(data):
    """Handle batch session upload with all logs"""
    if not os.path.exists(LOGS_FOLDER):
        os.makedirs(LOGS_FOLDER)

    session_id = data.get("sessionId", "unknown")
    username = data.get("username", "unknown")
    start_time = data.get("startTime", "N/A")
    end_time = data.get("endTime", "N/A")
    duration = data.get("durationFormatted", "N/A")
    total_logs = data.get("totalLogs", 0)
    info_count = data.get("infoCount", 0)
    warn_count = data.get("warningCount", 0)
    error_count = data.get("errorCount", 0)
    logs = data.get("logs", [])

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(
        LOGS_FOLDER, f"session_{username}_{timestamp}_{session_id}.txt"
    )

    with open(filename, "w", encoding="utf-8") as f:
        f.write(f"{'=' * 60}\n")
        f.write(f"   WINDUI SESSION LOG UPLOAD\n")
        f.write(f"{'=' * 60}\n")
        f.write(f"Session ID: {session_id}\n")
        f.write(f"User: {username} (ID: {data.get('userId', 'N/A')})\n")
        f.write(f"Start Time: {start_time}\n")
        f.write(f"End Time: {end_time}\n")
        f.write(f"Duration: {duration}\n")
        f.write(f"{'=' * 60}\n")
        f.write(f"Total Logs: {total_logs}\n")
        f.write(f"  - Info: {info_count}\n")
        f.write(f"  - Warning: {warn_count}\n")
        f.write(f"  - Error: {error_count}\n")
        f.write(f"{'=' * 60}\n\n")

        for log in logs:
            level = log.get("level", "Info")
            time = log.get("time", "??:??:??")
            message = log.get("message", "")
            f.write(f"[{time}][{level}] {message}\n")

    print(f"\n{Colors.GREEN}{'=' * 50}{Colors.RESET}")
    print(f"{Colors.GREEN}   SESSION UPLOAD RECEIVED{Colors.RESET}")
    print(f"{Colors.GREEN}{'=' * 50}{Colors.RESET}")
    print(f"{Colors.CYAN}User:{Colors.RESET} {username}")
    print(f"{Colors.CYAN}Session:{Colors.RESET} {session_id}")
    print(f"{Colors.CYAN}Duration:{Colors.RESET} {duration}")
    print(f"{Colors.CYAN}Total Logs:{Colors.RESET} {total_logs}")
    print(f"  {Colors.GRAY}Info: {info_count}{Colors.RESET}")
    print(f"  {Colors.YELLOW}Warning: {warn_count}{Colors.RESET}")
    print(f"  {Colors.RED}Error: {error_count}{Colors.RESET}")
    print(f"{Colors.GREEN}Saved to:{Colors.RESET} {filename}")
    print(f"{Colors.GREEN}{'=' * 50}{Colors.RESET}\n")

    return filename


def save_to_file(data):
    global session_file

    if not os.path.exists(LOGS_FOLDER):
        os.makedirs(LOGS_FOLDER)

    if session_file is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        username = data.get("username", "unknown")
        session_file = os.path.join(LOGS_FOLDER, f"session_{username}_{timestamp}.txt")

        with open(session_file, "w", encoding="utf-8") as f:
            f.write(f"=== WindUI Log Session ===\n")
            f.write(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"User: {username} (ID: {data.get('userId', 'N/A')})\n")
            f.write(f"{'=' * 40}\n\n")

    with open(session_file, "a", encoding="utf-8") as f:
        level = data.get("level", "Info")
        message = data.get("message", "")
        time = data.get("time", datetime.now().strftime("%H:%M:%S"))
        f.write(f"[{time}][{level}] {message}\n")


class LogHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header(
            "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"
        )
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, format, *args):
        msg = str(args[0]) if args else ""
        if "/logs" not in msg:
            print(f"{Colors.GRAY}[HTTP] {msg}{Colors.RESET}")

    def do_POST(self):
        if self.path == "/logs" or self.path.startswith("/logs?"):
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")

            try:
                data = json.loads(body)

                if data.get("type") == "session_upload":
                    handle_session_upload(data)
                else:
                    log_to_terminal(data)
                    save_to_file(data)

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"status":"ok"}')
            except json.JSONDecodeError as e:
                print(f"{Colors.RED}[ERROR] Invalid JSON: {e}{Colors.RESET}")
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/logs":
            query = parse_qs(parsed.query)
            if "data" in query:
                try:
                    data = json.loads(query["data"][0])
                    log_to_terminal(data)
                    save_to_file(data)
                except:
                    pass

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
            return

        if SERVE_FILES:
            super().do_GET()
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


def start_server():
    local_ip = get_local_ip()

    # Serve from parent directory (Project Root)
    # Because this script is in /Server folder
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    os.chdir(parent_dir)

    print(f"""
{Colors.CYAN}{"=" * 50}
   WindUI Remote Log Server v2.1
{"=" * 50}{Colors.RESET}
{Colors.GREEN}[✓]{Colors.RESET} Server URL: {Colors.BOLD}http://{local_ip}:{PORT}{Colors.RESET}
{Colors.GREEN}[✓]{Colors.RESET} Log Endpoint: {Colors.BOLD}http://{local_ip}:{PORT}/logs{Colors.RESET}
{Colors.GREEN}[✓]{Colors.RESET} Logs Folder: {Colors.BOLD}{os.path.abspath(LOGS_FOLDER)}{Colors.RESET}
{Colors.GREEN}[✓]{Colors.RESET} Serving from: {Colors.BOLD}{os.getcwd()}{Colors.RESET}
{Colors.CYAN}{"=" * 50}{Colors.RESET}
{Colors.YELLOW}[!] Waiting for logs... (Ctrl+C to stop){Colors.RESET}
""")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), LogHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print(f"\n{Colors.RED}[!] Server stopped.{Colors.RESET}")
            if session_file:
                print(f"{Colors.GREEN}[✓] Logs saved to: {session_file}{Colors.RESET}")


def main():
    local_ip = get_local_ip()

    print(f"""
{Colors.CYAN}╔══════════════════════════════════════════════════╗
║       WindUI Remote Log Server v2.1              ║
╚══════════════════════════════════════════════════╝{Colors.RESET}
{Colors.GREEN}[i]{Colors.RESET} Current IP: {Colors.BOLD}{local_ip}{Colors.RESET}
{Colors.GREEN}[i]{Colors.RESET} Port: {Colors.BOLD}{PORT}{Colors.RESET}
""")

    while True:
        choice = show_menu()

        if choice == "1":
            start_server()
            break
        elif choice == "2":
            print(f"\n{Colors.CYAN}[*] Updating IP to: {local_ip}:{PORT}{Colors.RESET}")

            # Temporary chdir to find files if needed, but update_ip_in_files handles paths absolute/relative to project
            updated = update_ip_in_files(local_ip)
            if updated:
                print(
                    f"\n{Colors.GREEN}[✓] Updated {len(updated)} file(s){Colors.RESET}"
                )
            else:
                print(f"\n{Colors.YELLOW}[!] No files were updated{Colors.RESET}")
        elif choice == "0":
            print(f"\n{Colors.CYAN}Goodbye!{Colors.RESET}\n")
            break
        else:
            print(f"{Colors.RED}Invalid choice{Colors.RESET}")


if __name__ == "__main__":
    main()
