#!/bin/bash
# Regression tests for config/agent.Rprofile self-location.
#
# languageserver runs lint passes in callr child processes, and callr rewrites
# R_PROFILE_USER in those children to point at its own chained temp profile
# (which sources the original). A profile that locates itself through
# R_PROFILE_USER therefore looks for agent.lintr in callr's temp directory and
# silently falls back to lintr's default linters. The fix (47fc946) locates the
# plugin via CLAUDE_PLUGIN_ROOT — exported by Claude Code and inherited
# unchanged by callr children — with R_PROFILE_USER as the fallback for
# non-Claude launches.
#
# Each scenario runs R's real startup path: Rscript with the --vanilla flag set
# MINUS --no-init-file, so R itself sources R_PROFILE_USER exactly as in
# production. (--vanilla would not work here: --no-init-file makes R scrub
# R_PROFILE_USER from the process environment, so a profile sourced explicitly
# under --vanilla can never see the decoy value the callr scenario depends on.)
# The callr child is simulated by pointing R_PROFILE_USER at a decoy chained
# profile that source()s the profile under test — precisely callr's mechanism.
# HOME points at an empty temp dir so the user's real ~/.Rprofile cannot
# interfere, and the -e expression reads back getOption("lintr.linter_file").
#
# Usage: tests/diagnostics/test-agent-profile.sh
# Exit:  0 if every test passes, 1 otherwise.
#
# Overridable so the suite can be pointed at the pre-fix profile to confirm the
# callr-child test actually fails against the bug it claims to cover:
#   git show e7c7d34:config/agent.Rprofile > /tmp/prefix-profile.R
#   AGENT_PROFILE=/tmp/prefix-profile.R tests/diagnostics/test-agent-profile.sh

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
agent_profile="${AGENT_PROFILE:-$repo_root/config/agent.Rprofile}"
real_lintr="$repo_root/config/agent.lintr"

# Hard prerequisites — these are the fixture, not the behaviour under test, so
# their absence is an environment error rather than a test failure.
if ! command -v Rscript &>/dev/null; then
  echo "error: Rscript is required to run these tests" >&2
  exit 1
fi
if [[ ! -f "$agent_profile" ]]; then
  echo "error: profile under test not found: $agent_profile" >&2
  exit 1
fi
if [[ ! -f "$real_lintr" ]]; then
  echo "error: expected agent lintr config not found: $real_lintr" >&2
  exit 1
fi

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/agent-profile-tests.XXXXXX")
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

# assert_contains <label> <needle> <haystack>
# For assertions that must hold regardless of stray profile chatter, so that one
# defect (noise on stdout) cannot mask an unrelated one (profile never sourced).
assert_contains() {
  if [[ "$3" == *"$2"* ]]; then
    pass "$1"
  else
    fail "$1" "expected to find [$2] in [$3]"
  fi
}

# The profile's has_project_lintr() walks UP from getwd() to the filesystem
# root, so a stray .lintr in any ancestor of the temp cwd would flip every
# scenario to the "project config wins" branch. R sees the kernel-resolved
# (physical) cwd, so walk the physical path. In practice /private/tmp and
# /var/folders trees carry no .lintr, but verify rather than assume.
guard_dir=$(cd "$tmp_root" && pwd -P)
while :; do
  if [[ -e "$guard_dir/.lintr" || -e "$guard_dir/.lintr.R" ]]; then
    echo "error: $guard_dir contains a .lintr/.lintr.R, which would shadow" >&2
    echo "every scenario below. Set TMPDIR to a directory with no .lintr in" >&2
    echo "any ancestor and re-run." >&2
    exit 1
  fi
  [[ "$guard_dir" == "/" ]] && break
  guard_dir=$(dirname "$guard_dir")
done

# Empty HOME: the profile sources ~/.Rprofile when one exists, and the real
# user profile could set lintr.linter_file (or print) and corrupt the run.
tmp_home="$tmp_root/home"
mkdir -p "$tmp_home"

# A talkative user profile: cat()/print() at startup land on fd 1, which is the
# LSP's stdio channel (.lsp.json runs `R --no-echo -e "languageserver::run()"`).
chatty_home="$tmp_root/home-chatty"
mkdir -p "$chatty_home"
# It also sets an option, so a suppression bug that skips the user's profile
# entirely cannot pass the stdout assertions vacuously.
cat > "$chatty_home/.Rprofile" <<'EOF'
cat("CHATTY-CAT\n")
print("CHATTY-PRINT")
options(sentinel_user = TRUE)
EOF

# A user profile that throws partway. R halts on this natively, for every R
# session the user runs; the agent profile must not paper over it.
broken_home="$tmp_root/home-broken"
mkdir -p "$broken_home"
cat > "$broken_home/.Rprofile" <<'EOF'
options(sentinel_before = TRUE)
stop("renv activate failed")
EOF

# Stand-in for callr's chained temp profile: a file in a directory containing
# no agent.lintr, which source()s the original profile — callr's exact
# mechanism. From inside the profile, R_PROFILE_USER names this decoy, not the
# profile itself.
decoy_dir="$tmp_root/callr-decoy"
mkdir -p "$decoy_dir"
decoy="$decoy_dir/fake-profile.R"
printf 'source("%s")\n' "$agent_profile" > "$decoy"

# Temp cwds for the R runs: one with no project lintr config anywhere up its
# tree (guarded above), one with its own .lintr.
clean_cwd="$tmp_root/work/clean"
project_cwd="$tmp_root/work/project"
mkdir -p "$clean_cwd" "$project_cwd"
printf 'linters: lintr::linters_with_defaults()\n' > "$project_cwd/.lintr"

# Staged copy of the profile under test with agent.lintr beside it, for the
# non-Claude fallback scenario: R_PROFILE_USER must point at a profile whose
# own directory holds agent.lintr, and staging keeps that true even when
# AGENT_PROFILE points at an extracted revision sitting in /tmp.
stage_config="$tmp_root/fallback-plugin/config"
mkdir -p "$stage_config"
cp "$agent_profile" "$stage_config/agent.Rprofile"
cp "$real_lintr" "$stage_config/agent.lintr"

# Everything --vanilla implies except --no-init-file, which must stay off so R
# sources R_PROFILE_USER at startup (and leaves the env var visible to it).
r_flags=(--no-site-file --no-environ --no-save --no-restore)

# run_profile <cwd> [env args...]
# Runs Rscript under the given env (which must set R_PROFILE_USER; R's startup
# sources it) and prints the resulting lintr.linter_file option after a
# sentinel. Sets globals `out` and `run_exit`. Asserting `out` against
# "SENTINEL:<value>" exactly checks the option AND that the profile wrote
# nothing to stdout — stray output would corrupt the LSP stream. Not echoing
# from the function: a caller writing out=$(run_profile ...) would lose the
# exit status in the subshell.
r_query='v <- getOption("lintr.linter_file"); cat("SENTINEL:", if (is.null(v)) "NULL" else v, sep = "")'
out=""
run_exit=0
run_profile() {
  local cwd="$1"
  shift
  out=$(cd "$cwd" && env "$@" Rscript "${r_flags[@]}" -e "$r_query" 2>/dev/null)
  run_exit=$?
}

# run_silent <cwd> [env args...]
# Same, but asks R to print nothing: any stdout at all is the profile's.
run_silent() {
  local cwd="$1"
  shift
  out=$(cd "$cwd" && env "$@" Rscript "${r_flags[@]}" -e 'invisible(NULL)' 2>/dev/null)
  run_exit=$?
}

# run_expr <cwd> <r_expr> [env args...]
# Same plumbing, arbitrary read-back expression.
run_expr() {
  local cwd="$1" expr="$2"
  shift 2
  out=$(cd "$cwd" && env "$@" Rscript "${r_flags[@]}" -e "$expr" 2>/dev/null)
  run_exit=$?
}

echo "== profile parses =="

if Rscript --vanilla -e "invisible(parse(\"$agent_profile\"))" >/dev/null 2>&1; then
  pass "profile is syntactically valid R"
else
  fail "profile is syntactically valid R" "parse() failed for $agent_profile"
fi

echo "== callr child: decoy R_PROFILE_USER, real CLAUDE_PLUGIN_ROOT =="

# THE regression assertion. In a callr lint child R_PROFILE_USER points at
# callr's own temp profile (which chain-sources the real one); only
# CLAUDE_PLUGIN_ROOT still names the plugin. The pre-fix profile resolved
# agent.lintr relative to the decoy, found nothing, and silently left lintr on
# its default linters.
run_profile "$clean_cwd" \
  HOME="$tmp_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_eq "callr child: exit 0" 0 "$run_exit"
assert_eq "callr child: resolves the real agent.lintr" \
  "SENTINEL:$real_lintr" "$out"

run_silent "$clean_cwd" \
  HOME="$tmp_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_eq "callr child: profile writes nothing to stdout" "" "$out"

echo "== non-Claude fallback: no CLAUDE_PLUGIN_ROOT =="

# Outside Claude (tests, manual runs) only R_PROFILE_USER names the profile,
# and it points at the true path; the fallback branch must still find the
# agent.lintr sitting beside the profile.
run_profile "$clean_cwd" \
  -u CLAUDE_PLUGIN_ROOT HOME="$tmp_home" \
  R_PROFILE_USER="$stage_config/agent.Rprofile"
assert_eq "fallback: exit 0" 0 "$run_exit"
assert_eq "fallback: resolves agent.lintr beside the profile" \
  "SENTINEL:$stage_config/agent.lintr" "$out"

echo "== project .lintr wins =="

# Same env as the callr-child scenario, but the cwd has its own .lintr: the
# profile must leave lintr.linter_file alone (an absolute-path option would
# override the project config, and the agent must not see fewer lints than CI).
run_profile "$project_cwd" \
  HOME="$tmp_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_eq "project .lintr: exit 0" 0 "$run_exit"
assert_eq "project .lintr: option stays NULL" "SENTINEL:NULL" "$out"

echo "== user ~/.Rprofile: stdout suppressed, errors not swallowed =="

# The user's profile may cat()/print(); that output would corrupt the LSP
# stream. The agent profile sinks R-level stdout to nullfile() around the
# source() call. utils::capture.output is NOT an option here: only base and
# methods are attached while .Rprofile runs, so it does not exist yet, and a
# tryCatch that swallows the resulting "could not find function" would silently
# skip the user's profile altogether.
# Assert first that the user's profile RAN. Without this, a suppression bug that
# skips ~/.Rprofile altogether satisfies every stdout assertion below for the
# wrong reason. assert_contains, not assert_eq: a profile that both leaks stdout
# and sources correctly should fail only the leak assertion.
run_expr "$clean_cwd" 'cat("SENTINEL:", isTRUE(getOption("sentinel_user")), sep = "")' \
  HOME="$chatty_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_contains "chatty ~/.Rprofile: user profile is actually sourced" \
  "SENTINEL:TRUE" "$out"

run_silent "$clean_cwd" \
  HOME="$chatty_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_eq "chatty ~/.Rprofile: exit 0" 0 "$run_exit"
assert_eq "chatty ~/.Rprofile: nothing reaches stdout" "" "$out"

# The sink must be balanced afterwards, or every later LSP write vanishes into
# nullfile(). assert_contains keeps this independent of the leak assertion above.
run_profile "$clean_cwd" \
  HOME="$chatty_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
assert_contains "chatty ~/.Rprofile: R still writes stdout afterwards (sink balanced)" \
  "SENTINEL:$real_lintr" "$out"

# A throwing ~/.Rprofile must still halt R. Continuing would leave the profile
# half-applied (.libPaths() unset), and languageserver would then flood the
# agent with bogus "no symbol named X" diagnostics against a broken library set.
# A dead server is loud; a half-configured one lies.
run_profile "$clean_cwd" \
  HOME="$broken_home" R_PROFILE_USER="$decoy" CLAUDE_PLUGIN_ROOT="$repo_root"
if [[ "$run_exit" -ne 0 ]]; then
  pass "broken ~/.Rprofile: R halts rather than limping on partial state"
else
  fail "broken ~/.Rprofile: R halts rather than limping on partial state" \
    "expected nonzero exit, got 0 (error was swallowed)"
fi

echo "== bogus everything: degrade silently =="

# No CLAUDE_PLUGIN_ROOT and R_PROFILE_USER pointing at the decoy: no
# agent.lintr is findable. The profile must leave the option unset and exit
# cleanly — an error here would take down the language server.
run_profile "$clean_cwd" \
  -u CLAUDE_PLUGIN_ROOT HOME="$tmp_home" R_PROFILE_USER="$decoy"
assert_eq "bogus env: exit 0" 0 "$run_exit"
assert_eq "bogus env: option stays NULL" "SENTINEL:NULL" "$out"

echo
printf '%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
