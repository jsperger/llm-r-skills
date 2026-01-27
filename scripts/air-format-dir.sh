#!/bin/bash
set -euo pipefail

# PreToolUse hook: Format all R files before git commit
# Runs on Bash tool use, checks if command is git commit

# Read hook input from stdin
input=$(cat)

# Extract the bash command
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if this is a commit or PR command
if [[ "$command" == *"git commit"* ]] || [[ "$command" == *"gh pr create"* ]]; then
  # Format all R files in the project
  air format . 2>/dev/null || true

  # If formatting changed files, stage them
  if [[ "$command" == *"git commit"* ]]; then
    git add -u '*.R' 2>/dev/null || true
  fi
fi

# Always allow the command to proceed
exit 0
