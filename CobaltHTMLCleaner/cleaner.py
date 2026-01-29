import re
import os
import glob
import time
import json

# Configuration
# Script is now located at root of CobaltHTMLCleaner
# Input folder is ./input
# Output folder is ./output
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(BASE_DIR, "input")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

HEADER_TEXT = """--[[
    CONTEXT: ROBLOX AUTOMATION / LOG ANALYSIS
    SOURCE: Extracted from Cobalt Executor Logs (HTML Session)
    
    SUMMARY:
    This script represents a CLEANED REPLAY of gameplay actions. 
    It has been compacted for AI readability (HTML-Only Mode).
]]
"""

def process_html_content(content):
    # Extract JSON blobs
    dict_match = re.search(r'<script type="application/json" id="dictionary-data">\s*(.*?)\s*</script>', content, re.DOTALL)
    events_match = re.search(r'<script type="application/json" id="event-data">\s*(.*?)\s*</script>', content, re.DOTALL)
    
    if not dict_match or not events_match:
        print("  -> Error: Could not find JSON data in HTML")
        return []
        
    try:
        dictionary = json.loads(dict_match.group(1))
        raw_events = json.loads(events_match.group(1))
    except json.JSONDecodeError as e:
        print(f"  -> Error decoding JSON: {e}")
        return []

    cleaned_code = []
    unique_lines = set()

    for evt in raw_events:
        # Mapping:
        # e[2] = path index
        # e[3] = type index
        # e[6] = args index
        # e[7] = method index
        
        path = dictionary.get(str(evt[2]), "UnknownPath")
        args_raw = dictionary.get(str(evt[6]), "{}")
        method = dictionary.get(str(evt[7]), "FireServer")
        
        # Clean up args: Single line optimization
        # 1. Strip outer braces
        args_clean = args_raw.strip()
        if args_clean.startswith('{') and args_clean.endswith('}'):
             args_clean = args_clean[1:-1].strip()
        
        # 2. Collapse all newlines and multiple spaces into single spaces
        args_clean = re.sub(r'\s+', ' ', args_clean)
        
        # Construct line
        evt_type = dictionary.get(str(evt[3]), "")
        
        line = ""
        if "Client" in method or "Client" in evt_type:
             line = f'firesignal({path}.OnClientEvent, {args_clean})'
        else:
             line = f'{path}:{method}({args_clean})'
        
        # Deduplicate
        if line not in unique_lines:
            unique_lines.add(line)
            cleaned_code.append(line)
            
    return cleaned_code

def process_file(file_path):
    print(f"Processing: {os.path.basename(file_path)}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except Exception as e:
        print(f"  -> Error reading file: {e}")
        return

    cleaned_code = process_html_content(content)
    
    if not cleaned_code:
        print("  -> No events found or invalid HTML.")
        return

    base_name = os.path.splitext(os.path.basename(file_path))[0]
    output_path = os.path.join(OUTPUT_DIR, f"{base_name}_clean.lua")
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(HEADER_TEXT)
            f.write("\n")
            for line in cleaned_code:
                f.write(line + "\n")
        print(f"  -> Created: output/{os.path.basename(output_path)} ({len(cleaned_code)} lines)")
    except Exception as e:
        print(f"  -> Error writing output: {e}")

def get_html_files():
    # Only look in 'input' dir now
    return glob.glob(os.path.join(LOG_DIR, "*.html"))

def main():
    if not os.path.exists(LOG_DIR):
        print(f"Input directory not found: {LOG_DIR}")
        print("Please create an 'input' folder and place your .html files there.")
        input("Press Enter to exit...")
        return

    html_files = get_html_files()
    
    if not html_files:
        print(f"No .html files found in: {LOG_DIR}")
        print("Please place your Cobalt Session HTML files in the 'input' folder.")
        input("Press Enter to exit...")
        return
        
    print(f"Found {len(html_files)} HTML files in 'input' folder")
    print("-" * 30)
    print("1. Process Latest HTML")
    print("2. Process All HTML Files")
    print("3. Select HTML from List")
    print("-" * 30)
    
    choice = input("Enter option (1-3): ").strip()
    
    if choice == '1':
        latest_file = max(html_files, key=os.path.getmtime)
        print(f"\nTarget: {os.path.basename(latest_file)}")
        process_file(latest_file)
        
    elif choice == '2':
        print("\nTarget: All HTML Files")
        for f in html_files:
            process_file(f)
            
    elif choice == '3':
        print("\nAvailable HTML Files:")
        sorted_files = sorted(html_files, key=os.path.getmtime, reverse=True)
        
        for idx, f in enumerate(sorted_files):
            print(f"{idx+1}. {os.path.basename(f)}")
            
        try:
            selection = int(input("\nEnter number: "))
            if 1 <= selection <= len(sorted_files):
                selected_file = sorted_files[selection-1]
                print(f"\nTarget: {os.path.basename(selected_file)}")
                process_file(selected_file)
            else:
                print("Invalid number selected.")
        except ValueError:
            print("Invalid input. Please enter a number.")
            
    else:
        print("Invalid option selected.")

    print("\nDone.")
    time.sleep(2)

if __name__ == "__main__":
    main()
