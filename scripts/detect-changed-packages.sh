#!/bin/bash
set -euo pipefail

# Detect R packages with staged changes (for pre-commit)
# or all uncommitted changes (when --all flag is passed)
# Usage: detect-changed-packages.sh [--all]
# Output: One package root per line (deduplicated)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mode="staged"
if [[ "${1:-}" == "--all" ]]; then
  mode="all"
fi

# Get list of changed R files
if [[ "$mode" == "staged" ]]; then
  # Only staged changes (for commits)
  changed_files=$(git diff --cached --name-only --diff-filter=ACMR -- '*.R' 2>/dev/null || true)
else
  # All uncommitted changes (staged + unstaged)
  changed_files=$(git diff --name-only --diff-filter=ACMR HEAD -- '*.R' 2>/dev/null || true)
  # Also include untracked R files
  untracked=$(git ls-files --others --exclude-standard -- '*.R' 2>/dev/null || true)
  if [[ -n "$untracked" ]]; then
    changed_files="$changed_files"$'\n'"$untracked"
  fi
fi

if [[ -z "$changed_files" ]]; then
  exit 0
fi

# Find package roots for each changed file
declare -A seen_packages

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Get absolute path
  abs_file="$(pwd)/$file"

  # Find package root
  pkg_root=$("$SCRIPT_DIR/detect-package-root.sh" "$abs_file" 2>/dev/null || true)

  if [[ -n "$pkg_root" && -z "${seen_packages[$pkg_root]:-}" ]]; then
    seen_packages["$pkg_root"]=1
    echo "$pkg_root"
  fi
done <<< "$changed_files"
