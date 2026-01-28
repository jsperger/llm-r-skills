#!/bin/bash
set -euo pipefail

# LSP Test Harness for R Language Server
# Tests core LSP functionality and reports issues
# Usage: lsp-test-harness.sh [--fix]
#
# Output: JSON with test results and recommendations

fix_mode=false
if [[ "${1:-}" == "--fix" ]]; then
  fix_mode=true
fi

# Results accumulator
results=()
all_passed=true

# Helper to add result
add_result() {
  local test_name="$1"
  local passed="$2"
  local message="$3"
  local fix="${4:-}"

  results+=("$(jq -n \
    --arg name "$test_name" \
    --argjson passed "$passed" \
    --arg message "$message" \
    --arg fix "$fix" \
    '{name: $name, passed: $passed, message: $message, fix: $fix}')")

  if [[ "$passed" == "false" ]]; then
    all_passed=false
  fi
}

# Test 1: Check if R is installed
if command -v R &>/dev/null; then
  r_version=$(R --version 2>&1 | head -1)
  add_result "R Installation" true "$r_version"
else
  add_result "R Installation" false "R is not installed or not in PATH" "Install R from https://cran.r-project.org/"
fi

# Test 2: Check if languageserver package is installed
if Rscript -e "library(languageserver)" 2>/dev/null; then
  ls_version=$(Rscript -e "cat(as.character(packageVersion('languageserver')))" 2>/dev/null)
  add_result "languageserver Package" true "Version $ls_version installed"
else
  add_result "languageserver Package" false "languageserver package not installed" \
    "Run: install.packages('languageserver')"

  if [[ "$fix_mode" == true ]]; then
    echo "Attempting to install languageserver..." >&2
    Rscript -e "install.packages('languageserver', repos='https://cloud.r-project.org')" 2>&1 || true
  fi
fi

# Test 3: Check if lintr is installed (for diagnostics)
if Rscript -e "library(lintr)" 2>/dev/null; then
  lintr_version=$(Rscript -e "cat(as.character(packageVersion('lintr')))" 2>/dev/null)
  add_result "lintr Package" true "Version $lintr_version installed"
else
  add_result "lintr Package" false "lintr package not installed (affects diagnostics)" \
    "Run: install.packages('lintr')"

  if [[ "$fix_mode" == true ]]; then
    echo "Attempting to install lintr..." >&2
    Rscript -e "install.packages('lintr', repos='https://cloud.r-project.org')" 2>&1 || true
  fi
fi

# Test 4: Check if LSP can start
lsp_test=$(timeout 5 Rscript -e "
  suppressMessages(library(languageserver))
  cat('LSP can start')
" 2>&1) || lsp_test=""

if [[ "$lsp_test" == *"LSP can start"* ]]; then
  add_result "LSP Startup" true "Language server can initialize"
else
  add_result "LSP Startup" false "Language server failed to start: $lsp_test" \
    "Check R installation and languageserver package"
fi

# Test 5: Check .lsp.json configuration (if in project with one)
if [[ -f ".lsp.json" ]]; then
  if jq empty .lsp.json 2>/dev/null; then
    add_result "LSP Configuration" true ".lsp.json is valid JSON"
  else
    add_result "LSP Configuration" false ".lsp.json contains invalid JSON" \
      "Fix JSON syntax in .lsp.json"
  fi
elif [[ -f "$CLAUDE_PROJECT_DIR/.lsp.json" ]] 2>/dev/null; then
  if jq empty "$CLAUDE_PROJECT_DIR/.lsp.json" 2>/dev/null; then
    add_result "LSP Configuration" true ".lsp.json is valid JSON"
  else
    add_result "LSP Configuration" false ".lsp.json contains invalid JSON" \
      "Fix JSON syntax in .lsp.json"
  fi
else
  add_result "LSP Configuration" true "No .lsp.json found (using defaults)"
fi

# Test 6: Check if air formatter is available
if command -v air &>/dev/null; then
  air_version=$(air --version 2>&1 || echo "unknown")
  add_result "air Formatter" true "Version: $air_version"
else
  add_result "air Formatter" false "air formatter not installed" \
    "Install from https://github.com/posit-dev/air"
fi

# Build final output
results_json=$(printf '%s\n' "${results[@]}" | jq -s '.')

if [[ "$all_passed" == true ]]; then
  summary="All LSP tests passed. R language server should be functional."
else
  summary="Some LSP tests failed. See details for fixes."
fi

jq -n \
  --argjson results "$results_json" \
  --arg summary "$summary" \
  --argjson all_passed "$all_passed" \
  '{
    summary: $summary,
    all_passed: $all_passed,
    tests: $results
  }'
