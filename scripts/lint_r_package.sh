#!/bin/bash
set -euo pipefail

if [[ ! -f "DESCRIPTION" ]]; then
  echo "Error: DESCRIPTION file not found. This script must be run from the root of an R package." >&2
  exit 1
fi

Rscript -e 'lintr::lint_package()'