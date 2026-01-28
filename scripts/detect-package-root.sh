#!/bin/bash
set -euo pipefail

# Detect the R package root directory by walking up from a file path
# Usage: detect-package-root.sh <file_path>
# Output: Absolute path to package root (directory containing DESCRIPTION)
# Exit 1 if no package found

file_path="${1:-}"

if [[ -z "$file_path" ]]; then
  echo "Usage: detect-package-root.sh <file_path>" >&2
  exit 1
fi

# Convert to absolute path if relative
if [[ "$file_path" != /* ]]; then
  file_path="$(pwd)/$file_path"
fi

# Start from the file's directory (or the path itself if it's a directory)
if [[ -d "$file_path" ]]; then
  current_dir="$file_path"
else
  current_dir="$(dirname "$file_path")"
fi

# Walk up the directory tree looking for DESCRIPTION
while [[ "$current_dir" != "/" ]]; do
  if [[ -f "$current_dir/DESCRIPTION" ]]; then
    echo "$current_dir"
    exit 0
  fi
  current_dir="$(dirname "$current_dir")"
done

# No package found
exit 1
