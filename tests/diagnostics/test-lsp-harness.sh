#!/bin/bash
# Diagnostic tests for scripts/lsp-test-harness.sh
#
# These are deterministic assertions about the harness's own behaviour, run
# without a model in the loop. See README.md in this directory for what each
# test establishes and why.
#
# Usage: tests/diagnostics/test-lsp-harness.sh
# Exit:  0 if every test passes, 1 otherwise.

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Overridable so the suite can be pointed at an older revision of the harness to
# confirm these tests actually fail against the bugs they claim to cover:
#   git show <sha>:scripts/lsp-test-harness.sh > /tmp/old.sh && chmod +x /tmp/old.sh
#   LSP_HARNESS=/tmp/old.sh tests/diagnostics/test-lsp-harness.sh
harness="${LSP_HARNESS:-$repo_root/scripts/lsp-test-harness.sh}"

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/lsp-harness-tests.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT

passed=0
failed=0

pass() {
  printf '  ok   %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf '  FAIL %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '       %s\n' "$2"
  fi
  failed=$((failed + 1))
}

# assert_eq <label> <expected> <actual>
assert_eq() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1" "expected [$2], got [$3]"
  fi
}

# assert_json <label> <text>
# Non-emptiness is checked first and separately: `jq empty` exits 0 on empty
# input, so "parses as JSON" alone would be satisfied by the very bug these
# tests exist to catch (harness dies before writing anything to stdout).
assert_json() {
  if [[ -z "$2" ]]; then
    fail "$1" "stdout was empty"
  elif printf '%s' "$2" | jq empty 2>/dev/null; then
    pass "$1"
  else
    fail "$1" "not valid JSON: ${2:0:120}"
  fi
}

# Commands the harness (and R itself) may legitimately reach for. A sandbox
# PATH is built from this list minus whatever a given test wants absent, so a
# test can prove the harness copes with a missing tool rather than merely
# assuming it would.
sandbox_tools=(
  sh rm mv sed uname cat dirname basename which grep tr mkdir ls expr sort
  awk printf head env jq R Rscript air timeout gtimeout
)

# make_sandbox <dir> [tool-to-exclude ...]
# Populates <dir> with symlinks to sandbox_tools, skipping the excluded ones.
make_sandbox() {
  local dir="$1"
  shift
  mkdir -p "$dir"
  local tool excluded resolved
  for tool in "${sandbox_tools[@]}"; do
    excluded=false
    for e in "$@"; do
      [[ "$tool" == "$e" ]] && excluded=true
    done
    [[ "$excluded" == true ]] && continue
    if resolved=$(command -v "$tool" 2>/dev/null); then
      ln -sf "$resolved" "$dir/$tool"
    fi
  done
}

# run_harness <sandbox-dir-or-empty> <cwd> [env assignments...]
# Sets globals `out` and `run_exit`. Deliberately not echoing its output: a
# caller writing out=$(run_harness ...) would run it in a subshell and lose the
# exit status, which is half of what these tests assert on.
# The harness is invoked by absolute path so its `#!/bin/bash` shebang resolves
# regardless of the sandbox PATH.
out=""
run_exit=0
run_harness() {
  local sandbox="$1" cwd="$2"
  shift 2
  local -a env_args=("$@")
  if [[ -n "$sandbox" ]]; then
    env_args+=("PATH=$sandbox")
  fi
  out=$(cd "$cwd" && env "${env_args[@]}" "$harness" 2>/dev/null)
  run_exit=$?
}

# Directory guaranteed to contain no .lsp.json, so Test 5's `elif` branch is
# the one that gets exercised.
no_config_dir="$tmp_root/no-config"
mkdir -p "$no_config_dir"

echo "== static analysis =="

if bash -n "$harness" 2>/dev/null; then
  pass "harness parses (bash -n)"
else
  fail "harness parses (bash -n)"
fi

if command -v shellcheck &>/dev/null; then
  if shellcheck "$harness" >/dev/null 2>&1; then
    pass "harness is shellcheck-clean"
  else
    fail "harness is shellcheck-clean" "$(shellcheck "$harness" 2>&1 | head -5)"
  fi
else
  echo "  skip shellcheck (not installed)"
fi

echo "== always emits JSON =="

# The harness's whole purpose is to report on a broken environment. Any input
# that makes it die before printing JSON is a defeat of that purpose, so every
# degraded-environment test below asserts on parseable stdout + exit 0, not
# just on the absence of a crash.

run_harness "" "$repo_root" -u CLAUDE_PROJECT_DIR
assert_eq "healthy env: exit 0" 0 "$run_exit"
assert_json "healthy env: stdout is non-empty valid JSON" "$out"
assert_eq "healthy env: reports 6 tests" 6 "$(printf '%s' "$out" | jq '.tests | length')"

echo "== missing jq (regression: PR #1 review) =="

# add_result() shells out to jq, and `results+=("$(jq ...)")` is an assignment
# whose exit status trips `set -e`. Before the fix the harness died at 127 with
# empty stdout — the single worst failure mode for a diagnostic.
sb_nojq="$tmp_root/sb-nojq"
make_sandbox "$sb_nojq" jq
run_harness "$sb_nojq" "$no_config_dir" -u CLAUDE_PROJECT_DIR
assert_eq "no jq: exit 0" 0 "$run_exit"
assert_json "no jq: stdout is still non-empty valid JSON" "$out"
assert_eq "no jq: all_passed is false" false "$(printf '%s' "$out" | jq '.all_passed')"
assert_eq "no jq: names jq as the failure" jq "$(printf '%s' "$out" | jq -r '.tests[0].name')"

echo "== missing R (regression: PR #1 review) =="

# Copilot claimed `set -e` would abort here. It does not: these Rscript calls
# sit in `if` conditions, where `set -e` is suspended. The real defect was a
# misdiagnosis — three tests blaming missing packages on a machine with no R,
# and telling the user to run install.packages() with no R to run it in.
sb_nor="$tmp_root/sb-nor"
make_sandbox "$sb_nor" R Rscript
run_harness "$sb_nor" "$no_config_dir" -u CLAUDE_PROJECT_DIR
assert_eq "no R: exit 0 (no set -e abort)" 0 "$run_exit"
assert_eq "no R: reports 6 tests" 6 "$(printf '%s' "$out" | jq '.tests | length')"
assert_eq "no R: R Installation fails" false \
  "$(printf '%s' "$out" | jq '.tests[] | select(.name=="R Installation") | .passed')"

# The diagnostic value is in the *message*: "cannot check" is honest,
# "not installed" is a fabrication the harness cannot support.
for t in "languageserver Package" "lintr Package" "LSP Startup"; do
  msg=$(printf '%s' "$out" | jq -r --arg t "$t" '.tests[] | select(.name==$t) | .message')
  case "$msg" in
    *"Cannot check"*) pass "no R: '$t' says it cannot check" ;;
    *) fail "no R: '$t' says it cannot check" "got: $msg" ;;
  esac
done

echo "== missing timeout and gtimeout (regression: PR #1 review) =="

# Stock macOS ships neither; coreutils provides gtimeout. Before the fix the
# LSP Startup test reported "failed to start:" with an empty message on any
# such machine — a false negative attributable to the harness, not to R.
sb_nots="$tmp_root/sb-nots"
make_sandbox "$sb_nots" timeout gtimeout
if command -v Rscript &>/dev/null; then
  run_harness "$sb_nots" "$no_config_dir" -u CLAUDE_PROJECT_DIR
  assert_eq "no timeout: exit 0" 0 "$run_exit"
  assert_eq "no timeout: LSP Startup still passes" true \
    "$(printf '%s' "$out" | jq '.tests[] | select(.name=="LSP Startup") | .passed')"
else
  echo "  skip no-timeout test (needs a working Rscript to be meaningful)"
fi

echo "== unset CLAUDE_PROJECT_DIR (regression: PR #1 review) =="

# `[[ -f "$CLAUDE_PROJECT_DIR/.lsp.json" ]] 2>/dev/null` expanded an unset var
# under `set -u`: exit 1, no output, and the 2>/dev/null hid the reason. The
# variable is unset whenever the harness runs outside a Claude session, i.e.
# every manual invocation.
run_harness "" "$no_config_dir" -u CLAUDE_PROJECT_DIR
assert_eq "unset CLAUDE_PROJECT_DIR: exit 0" 0 "$run_exit"
assert_eq "unset CLAUDE_PROJECT_DIR: reaches the else branch" \
  "No .lsp.json found (using defaults)" \
  "$(printf '%s' "$out" | jq -r '.tests[] | select(.name=="LSP Configuration") | .message')"

echo "== .lsp.json discovery =="

# cwd takes precedence; CLAUDE_PROJECT_DIR is the fallback. Both branches are
# asserted so a future refactor cannot silently collapse them into one.
valid_dir="$tmp_root/valid-cwd"
mkdir -p "$valid_dir"
printf '{"r": {}}\n' > "$valid_dir/.lsp.json"
run_harness "" "$valid_dir" -u CLAUDE_PROJECT_DIR
assert_eq "valid .lsp.json in cwd: config test passes" true \
  "$(printf '%s' "$out" | jq '.tests[] | select(.name=="LSP Configuration") | .passed')"

run_harness "" "$no_config_dir" "CLAUDE_PROJECT_DIR=$valid_dir"
assert_eq "valid .lsp.json via CLAUDE_PROJECT_DIR: config test passes" true \
  "$(printf '%s' "$out" | jq '.tests[] | select(.name=="LSP Configuration") | .passed')"

bad_dir="$tmp_root/bad-cwd"
mkdir -p "$bad_dir"
printf '{"r": \n' > "$bad_dir/.lsp.json"
run_harness "" "$bad_dir" -u CLAUDE_PROJECT_DIR
assert_eq "malformed .lsp.json: exit 0" 0 "$run_exit"
assert_eq "malformed .lsp.json: config test fails" false \
  "$(printf '%s' "$out" | jq '.tests[] | select(.name=="LSP Configuration") | .passed')"

echo "== bash 3.2 compatibility =="

# /bin/bash on macOS is 3.2.57, and that is what the harness's shebang selects
# for plugin users. Under `set -u`, bash 3.2 treats a naive "${arr[@]}" on an
# empty array as an unbound variable. The harness expands timeout_cmd as
# ${arr[@]+"${arr[@]}"} for exactly this reason; assert the hazard is real so
# nobody "simplifies" the guard away.
if [[ -x /bin/bash ]]; then
  if /bin/bash -c 'set -euo pipefail; a=(); echo "${a[@]}"' &>/dev/null; then
    echo "  note: this /bin/bash tolerates empty-array expansion under set -u"
  else
    pass "empty-array expansion under set -u is a real hazard on /bin/bash"
  fi

  if /bin/bash -c 'set -euo pipefail; a=(); printf "%s" "${a[@]+"${a[@]}"}"' &>/dev/null; then
    pass "the \${arr[@]+...} guard survives /bin/bash + set -u"
  else
    fail "the \${arr[@]+...} guard survives /bin/bash + set -u"
  fi

  out=$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR /bin/bash "$harness" 2>/dev/null)
  assert_eq "harness runs end-to-end under /bin/bash" 0 "$?"
  assert_json "harness emits non-empty valid JSON under /bin/bash" "$out"
else
  echo "  skip /bin/bash tests (not present)"
fi

echo
printf '%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
