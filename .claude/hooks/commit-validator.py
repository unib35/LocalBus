#!/usr/bin/env python3
"""
Commit message validator hook for LocalBus project.
Validates commit messages against the project's Git conventions.
"""
import json
import sys
import re

# Valid commit types
VALID_TYPES = [
    '[Feat]',
    '[Fix]',
    '[Refactor]',
    '[Design]',
    '[Test]',
    '[Docs]',
    '[Chore]',
    '[Add]',
    '[Del]',
    '[Remove]',
    '[Comment]',
    '[Setting]',
    '[Merge]',
    '[Perf]'
]

def validate_commit_message(message: str) -> tuple[bool, str]:
    """Validate commit message against conventions."""

    if not message or not message.strip():
        return False, "Commit message is empty"

    # Get first line (title)
    lines = message.strip().split('\n')
    title = lines[0].strip()

    # Check for type prefix
    has_valid_type = any(title.startswith(t) for t in VALID_TYPES)
    if not has_valid_type:
        return False, f"Commit title must start with a valid type: {', '.join(VALID_TYPES[:5])}..."

    # Check for colon after type
    if ']:' not in title:
        return False, "Missing colon after type. Format: [Type]: message"

    # Extract message after type
    match = re.match(r'\[[\w]+\]:\s*(.+)', title)
    if not match:
        return False, "Invalid format. Expected: [Type]: message"

    msg_content = match.group(1)

    # Check title length (50 chars for message part)
    if len(msg_content) > 50:
        return False, f"Commit message too long ({len(msg_content)} chars). Max 50 chars."

    # Check for period at end
    if msg_content.endswith('.'):
        return False, "Commit message should not end with a period"

    # Check for imperative mood (basic check - starts with capital)
    if msg_content and msg_content[0].islower():
        return False, "Commit message should start with a capital letter (imperative mood)"

    return True, "Valid commit message"


def main():
    try:
        # Read hook input from stdin
        input_data = json.load(sys.stdin)

        # Get the command being executed
        tool_input = input_data.get('tool_input', {})
        command = tool_input.get('command', '')

        # Only validate git commit commands
        if 'git commit' not in command:
            sys.exit(0)  # Not a commit command, allow

        # Try to extract commit message from -m flag
        match = re.search(r'-m\s+["\'](.+?)["\']', command)
        if not match:
            # Check for heredoc style
            match = re.search(r'-m\s+"\$\(cat <<[\'"]?EOF[\'"]?\n(.+?)\nEOF', command, re.DOTALL)

        if match:
            message = match.group(1)
            is_valid, reason = validate_commit_message(message)

            if not is_valid:
                print(f"❌ Commit Convention Error: {reason}", file=sys.stderr)
                print(f"\n📝 Expected format:", file=sys.stderr)
                print(f"   [Type]: Message (50 chars max, no period)", file=sys.stderr)
                print(f"\n   Valid types: {', '.join(VALID_TYPES[:7])}", file=sys.stderr)
                sys.exit(2)  # Block the command
            else:
                print(f"✅ Commit message follows conventions")

        sys.exit(0)  # Allow the command

    except json.JSONDecodeError:
        # If we can't parse input, allow the command
        sys.exit(0)
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)  # Don't block on hook errors


if __name__ == '__main__':
    main()
