#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <file_path.R>"
    exit 1
fi

# Pass file path as argument to avoid shell injection in R expression
Rscript -e "args <- commandArgs(trailingOnly = TRUE); lintr::lint(args[1], parse_settings = TRUE)" "$1"