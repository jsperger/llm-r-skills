#!/bin/bash
set -euo pipefail

# Pre-commit/PR workflow for R packages
# Usage: r-pre-commit.sh <mode>
#   mode: "commit" (warn on failure) or "pr" (block on failure)
#
# Workflow:
# 1. Format R files with air
# 2. Run devtools::document() on packages with R/ changes
# 3. Run devtools::test() on all affected packages
#
# Input: JSON via stdin with tool_input.command
# Output: JSON with systemMessage (and exit 2 to block for PR mode)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read mode from argument or detect from command
mode="${1:-detect}"

# Read hook input from stdin
input=$(cat)

# If mode is "detect", parse the command to determine mode
if [[ "$mode" == "detect" ]]; then
  command=$(echo "$input" | jq -r '.tool_input.command // empty')

  if [[ "$command" == *"gh pr create"* ]]; then
    mode="pr"
  elif [[ "$command" == *"git commit"* ]]; then
    mode="commit"
  else
    # Not a commit or PR command, exit silently
    exit 0
  fi
fi

# Collect messages for final output
messages=()
has_errors=false

# Step 1: Format all R files in git root
git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if command -v air &>/dev/null; then
  air format "$git_root" 2>/dev/null || true

  # Stage any formatting changes (for commits only)
  if [[ "$mode" == "commit" ]]; then
    git add -u '*.R' 2>/dev/null || true
  fi
fi

# Step 2 & 3: Find affected packages and run document/test
packages=$("$SCRIPT_DIR/detect-changed-packages.sh" 2>/dev/null || true)

if [[ -z "$packages" ]]; then
  # No R packages affected, exit cleanly
  exit 0
fi

while IFS= read -r pkg_root; do
  [[ -z "$pkg_root" ]] && continue

  pkg_name=$(basename "$pkg_root")

  # Check if R/ directory has changes (for document)
  r_changes=$(git diff --cached --name-only -- "$pkg_root/R/" 2>/dev/null || true)

  # Run devtools::document() if R/ files changed
  if [[ -n "$r_changes" ]]; then
    doc_output=$(Rscript -e "devtools::document('$pkg_root')" 2>&1) || {
      messages+=("[$pkg_name] document() failed: $doc_output")
      has_errors=true
    }
  fi

  # Run devtools::test()
  test_output=$(Rscript -e "
    results <- devtools::test('$pkg_root', reporter = 'summary', stop_on_failure = FALSE)
    if (any(as.data.frame(results)\$failed > 0)) {
      quit(status = 1)
    }
  " 2>&1) || {
    messages+=("[$pkg_name] Tests failed:")
    messages+=("$test_output")
    has_errors=true
  }

done <<< "$packages"

# Build output
if [[ "$has_errors" == true ]]; then
  # Join messages with newlines
  full_message=$(printf '%s\n' "${messages[@]}")

  if [[ "$mode" == "pr" ]]; then
    # Block PR creation
    jq -n --arg msg "$full_message" '{
      "systemMessage": ("R package checks failed. Please fix before creating PR:\n" + $msg),
      "hookSpecificOutput": {
        "permissionDecision": "deny"
      }
    }' >&2
    exit 2
  else
    # Warn but allow commit
    jq -n --arg msg "$full_message" '{
      "systemMessage": ("R package checks found issues (continuing with commit):\n" + $msg)
    }'
    exit 0
  fi
fi

# All checks passed
exit 0
