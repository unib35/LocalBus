#!/usr/bin/env python3
"""
Swift file edit logger hook for LocalBus project.
Logs all Swift file edits for tracking changes.
"""
import json
import sys
import os
from datetime import datetime

LOG_FILE = os.path.expanduser('~/.claude/localbus-edits.log')

def main():
    try:
        # Read hook input from stdin
        input_data = json.load(sys.stdin)

        # Get file path from tool input
        tool_input = input_data.get('tool_input', {})
        file_path = tool_input.get('file_path', '')

        # Only log Swift files
        if not file_path.endswith('.swift'):
            sys.exit(0)

        # Ensure log directory exists
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

        # Log the edit
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        tool_name = input_data.get('tool_name', 'Unknown')

        with open(LOG_FILE, 'a') as f:
            f.write(f"[{timestamp}] {tool_name}: {file_path}\n")

        sys.exit(0)

    except Exception as e:
        # Don't fail on logging errors
        sys.exit(0)


if __name__ == '__main__':
    main()
