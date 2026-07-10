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

# jq is required to build the report. Without it we cannot use add_result, so
# emit a hand-rolled result and exit 0 (callers expect JSON on stdout).
if ! command -v jq &>/dev/null; then
  printf '%s\n' '{"summary":"jq is required but not installed.","all_passed":false,"tests":[{"name":"jq","passed":false,"message":"jq is not installed or not in PATH","fix":"Install jq (e.g. brew install jq)"}]}'
  exit 0
fi

# Locate a timeout implementation. macOS has neither unless coreutils is
# installed, in which case it is gtimeout.
timeout_cmd=()
if command -v timeout &>/dev/null; then
  timeout_cmd=(timeout 5)
elif command -v gtimeout &>/dev/null; then
  timeout_cmd=(gtimeout 5)
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
if ! command -v Rscript &>/dev/null; then
  add_result "languageserver Package" false "Cannot check: Rscript is not in PATH" \
    "Install R first, then install.packages('languageserver')"
elif Rscript -e "library(languageserver)" 2>/dev/null; then
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
if ! command -v Rscript &>/dev/null; then
  add_result "lintr Package" false "Cannot check: Rscript is not in PATH" \
    "Install R first, then install.packages('lintr')"
elif Rscript -e "library(lintr)" 2>/dev/null; then
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

# Test 4: Check languageserver/lintr version compatibility
# languageserver < 0.3.17 combined with lintr >= 3.3.0 silently ignores .lintr
# files (lintr's parse_settings regression; upstream languageserver #726). The
# plugin's agent lint profile depends on .lintr being honored, so this pairing
# must be a hard failure. Version comparison is done in R via packageVersion():
# bash 3.2 and BSD sort have no reliable -V.
if ! command -v Rscript &>/dev/null; then
  add_result "Version Compatibility" false "Cannot check: Rscript is not in PATH" \
    "Install R first, then install.packages(c('languageserver', 'lintr'))"
elif ! Rscript -e "library(languageserver); library(lintr)" 2>/dev/null; then
  add_result "Version Compatibility" false \
    "Cannot check: languageserver and/or lintr is not installed" \
    "Install both packages, then re-run this harness"
else
  ls_recent=$(Rscript -e "cat(packageVersion('languageserver') >= '0.3.17')" 2>/dev/null) || ls_recent=""
  lintr_recent=$(Rscript -e "cat(packageVersion('lintr') >= '3.3.0')" 2>/dev/null) || lintr_recent=""

  if [[ -z "$ls_recent" || -z "$lintr_recent" ]]; then
    add_result "Version Compatibility" false "Cannot check: failed to read package versions" \
      "Verify the languageserver and lintr installations, then re-run this harness"
  elif [[ "$ls_recent" == "TRUE" && "$lintr_recent" == "TRUE" ]]; then
    add_result "Version Compatibility" true \
      "languageserver ${ls_version:-unknown} and lintr ${lintr_version:-unknown} are compatible (.lintr settings are honored)"
  elif [[ "$lintr_recent" != "TRUE" ]]; then
    add_result "Version Compatibility" false \
      "lintr ${lintr_version:-unknown} is older than 3.3.0" \
      "Upgrade lintr to >= 3.3.0: install.packages('lintr')"
  else
    add_result "Version Compatibility" false \
      "languageserver ${ls_version:-unknown} with lintr ${lintr_version:-unknown}: .lintr files (including the plugin's agent lint profile) are silently ignored — diagnostics fall back to lintr defaults (upstream languageserver #726)" \
      "Upgrade languageserver to >= 0.3.17: install.packages('languageserver')"
  fi
fi

# Test 5: Check if LSP can start
# ${arr[@]+"${arr[@]}"} keeps an empty timeout_cmd from tripping `set -u` on
# bash 3.2, which is what macOS ships as /bin/bash.
if ! command -v Rscript &>/dev/null; then
  add_result "LSP Startup" false "Cannot check: Rscript is not in PATH" \
    "Install R and the languageserver package"
else
  lsp_test=$(${timeout_cmd[@]+"${timeout_cmd[@]}"} Rscript -e "
    suppressMessages(library(languageserver))
    cat('LSP can start')
  " 2>&1) || lsp_test=""

  if [[ "$lsp_test" == *"LSP can start"* ]]; then
    add_result "LSP Startup" true "Language server can initialize"
  else
    add_result "LSP Startup" false "Language server failed to start: $lsp_test" \
      "Check R installation and languageserver package"
  fi
fi

# Test 6: Check .lsp.json configuration (if in project with one)
if [[ -f ".lsp.json" ]]; then
  if jq empty .lsp.json 2>/dev/null; then
    add_result "LSP Configuration" true ".lsp.json is valid JSON"
  else
    add_result "LSP Configuration" false ".lsp.json contains invalid JSON" \
      "Fix JSON syntax in .lsp.json"
  fi
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" && -f "$CLAUDE_PROJECT_DIR/.lsp.json" ]]; then
  if jq empty "$CLAUDE_PROJECT_DIR/.lsp.json" 2>/dev/null; then
    add_result "LSP Configuration" true ".lsp.json is valid JSON"
  else
    add_result "LSP Configuration" false ".lsp.json contains invalid JSON" \
      "Fix JSON syntax in .lsp.json"
  fi
else
  add_result "LSP Configuration" true "No .lsp.json found (using defaults)"
fi

# Test 7: Check if air formatter is available
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
