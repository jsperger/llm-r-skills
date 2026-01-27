#!/bin/bash
set -euo pipefail

# PostToolUse hook: Format and lint R files after Edit/Write
# Reports lint issues but does not block (exit 0)

# Read hook input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only process R files
if [[ -z "$file_path" || "$file_path" != *.R ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Format with air (best-effort, don't fail if air not installed)
air format "$file_path" 2>/dev/null || true

# Run lintr and capture output
lint_output=$(Rscript -e "lintr::lint(\"$file_path\", parse_settings = TRUE)" 2>&1) || true

# If there are lint issues, report them via systemMessage
if [[ -n "$lint_output" && "$lint_output" != *"NULL"* && "$lint_output" != "" ]]; then
  # Safely construct JSON output using jq
  jq -n --arg path "$file_path" --arg output "$lint_output" \
    '{"systemMessage": ("Lintr found issues in " + $path + ":\n" + $output)}'
fi

# Always succeed (report only, don't block)
exit 0
