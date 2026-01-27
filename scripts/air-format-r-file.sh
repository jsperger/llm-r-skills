#!/bin/bash
set -euo pipefail

# Read hook input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only format R files
if [[ -n "$file_path" && "$file_path" == *.R ]]; then
  air format "$file_path" || true
fi

# Always succeed (formatting is best-effort)
exit 0  
