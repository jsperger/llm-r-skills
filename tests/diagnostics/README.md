# Diagnostic tests

Deterministic tests of the plugin's own shell tooling. No model in the loop, no
network, no MLflow — just assertions about what `scripts/lsp-test-harness.sh`
does under conditions we cannot reproduce on a healthy developer machine.

```bash
tests/diagnostics/test-lsp-harness.sh     # exits 0 if all pass
```

Requires `bash` and `jq`. `shellcheck` and `Rscript` are used if present and
skipped with a note if not.

## How these differ from `evals/`

The `evals/` harness (in the outer `developing-r-skills` workspace) drives
headless Claude Code sessions through R tasks and scores the resulting MLflow
traces with LLM judges. It answers *"did this plugin change make the model
better at R?"* — it is stochastic, slow, and its output is a pass-rate you
compare before/after.

These diagnostics answer *"is the shipped shell script correct?"* They are
deterministic, take a couple of seconds, and either pass or fail. A broken
harness would make `/r-lsp-diagnose` silently useless, and no eval would ever
notice, because an eval scores what the model produces, not whether a script the
model shells out to returned anything at all.

They live in the plugin repo rather than the outer workspace because they test a
file that ships with the plugin, and must keep working for anyone who checks out
`llm-r-skills` on its own.

## The governing invariant

**The harness must always print valid, non-empty JSON to stdout and exit 0 —
including, and especially, when the environment is broken.**

Everything below is a corollary. A diagnostic that dies when it encounters the
problem it exists to diagnose is worse than no diagnostic, because
`/r-lsp-diagnose` interpolates its output into a prompt: an empty stdout gives
the model nothing to explain, and a non-zero exit surfaces to the user as a
tooling error rather than as the actionable finding it should have been.

Note that `set -euo pipefail` is what makes this non-trivial. Each fix below is
a place where a perfectly ordinary shell idiom silently violated the invariant.

## What each test establishes

### Static analysis

| Test | Expected | Why |
| --- | --- | --- |
| `bash -n` parses | clean | Catches syntax breakage before any behavioural test can run and produce a confusing failure. |
| `shellcheck` clean | no findings | The bugs fixed in PR #1 are exactly the class shellcheck reasons about (unquoted expansions, unset vars, `set -e` interactions). Keeping it clean keeps that signal usable. |

### Healthy environment

Baseline. All six sub-tests present, valid JSON, exit 0. Establishes that the
degraded-environment tests below are measuring degradation and not a harness
that was broken to begin with.

### Missing `jq` — regression, PR #1 review

`add_result()` shells out to `jq`, and `results+=("$(jq -n ...)")` is an
*assignment*, whose exit status is the command substitution's. Under `set -e`,
a missing `jq` therefore killed the script at exit 127 with **empty stdout**.

- **Expected now:** hand-rolled JSON naming `jq` as the failed test, `all_passed:
  false`, exit 0.
- **Informative because:** it is the one dependency the harness cannot report on
  using its own reporting machinery. If this test fails, the harness has
  regressed into being unable to describe its own breakage.

### Missing `R` / `Rscript` — regression, PR #1 review

The review claimed `set -e` would abort at Test 2. It would not: those `Rscript`
calls sit in `if` conditions, where `set -e` is suspended. Running this suite
against the pre-fix harness demonstrates it — the pre-fix run *does* abort, but
at Test 5 (see below), not at Test 2.

The real defect was a **misdiagnosis**: on a machine with no R, the harness
reported "languageserver package not installed" and "lintr package not
installed", and advised the user to run `install.packages()` — with no R to run
it in. Three failures, one root cause, two of them fabricated.

- **Expected now:** `R Installation` fails; the three downstream tests report
  `Cannot check: Rscript is not in PATH` and point at installing R first.
- **Informative because:** it asserts on the *message*, not just the pass/fail
  bit. A diagnostic's value is entirely in whether its explanation is true. The
  distinction between "I checked and it's absent" and "I could not check" is the
  whole product.

### Missing `timeout` **and** `gtimeout` — regression, PR #1 review

Stock macOS ships neither; `gtimeout` arrives with Homebrew coreutils. The
pre-fix harness ran `timeout 5 Rscript ...`, whose failure was swallowed by
`|| lsp_test=""`, so `LSP Startup` reported `failed to start:` with an empty
message on every such machine.

- **Expected now:** `LSP Startup` passes, running `Rscript` without a timeout.
- **Informative because:** this is a false negative that blames R for a missing
  coreutils. It is invisible on any developer machine that has coreutils
  installed — which is why it needs a PATH sandbox to catch, and why it survived
  into review.

### Unset `CLAUDE_PROJECT_DIR` — regression, PR #1 review

`[[ -f "$CLAUDE_PROJECT_DIR/.lsp.json" ]] 2>/dev/null` expands an unset variable
under `set -u`: exit 1, no output. The `2>/dev/null` did not prevent the death,
it only **hid the reason**. `CLAUDE_PROJECT_DIR` is unset whenever the harness
runs outside a Claude session — i.e. on every manual invocation, including the
one a developer reaches for when debugging.

- **Expected now:** exit 0, and `LSP Configuration` reports `No .lsp.json found
  (using defaults)`.
- **Informative because:** it is the only fixed bug whose failure mode was
  *completely silent*. Exit 1, no stdout, no stderr. Worth a dedicated test for
  that reason alone.

### `.lsp.json` discovery

Asserts all three branches: valid config in cwd, valid config via
`CLAUDE_PROJECT_DIR`, and malformed JSON in cwd.

- **Informative because:** cwd-takes-precedence is load-bearing and untyped. A
  refactor could collapse the two lookup paths into one and nothing else in the
  repo would notice. The malformed case also confirms a bad `.lsp.json` is
  reported as a *finding* rather than crashing the reporter.

### bash 3.2 compatibility

`/bin/bash` on macOS is 3.2.57, and the harness's `#!/bin/bash` shebang selects
it for plugin users regardless of what their interactive shell is. Under
`set -u`, bash 3.2 treats `"${arr[@]}"` on an **empty** array as an unbound
variable and aborts.

The harness therefore expands its optional timeout prefix as
`${timeout_cmd[@]+"${timeout_cmd[@]}"}`. Two tests guard this:

1. The hazard is real on this `/bin/bash` (asserted, so the guard is not
   mistaken for cargo cult and "simplified" away by a later reader).
2. The guarded form survives `set -u` on that same `/bin/bash`.

Plus an end-to-end run under `/bin/bash` explicitly.

- **Informative because:** the obvious fix for the missing-`timeout` bug
  introduces exactly the crash the missing-`R` comment wrongly alleged. The
  guard is not stylistic.

## Verifying the tests actually test something

A regression test that passes against the broken code is worthless. Point the
suite at any earlier revision to check it fails:

```bash
git show <sha-before-fix>:scripts/lsp-test-harness.sh > /tmp/old.sh
chmod +x /tmp/old.sh
LSP_HARNESS=/tmp/old.sh tests/diagnostics/test-lsp-harness.sh
```

Against the commit immediately preceding the PR #1 fixes this reports
`13 passed, 14 failed`, with every failure in a section labelled
`regression: PR #1 review`. Against the current harness: `27 passed, 0 failed`.

Do this whenever you add a test here. It is the only way to know the assertion
discriminates. One assertion in the first draft of this suite (`stdout is valid
JSON`) passed against the broken harness, because `jq empty` accepts empty input
— precisely the bug it was meant to catch. Hence the separate non-emptiness
check in `assert_json`.

## Adding tests

Use `make_sandbox <dir> [tools-to-exclude...]` to build a PATH containing
everything the harness might reach for *except* the named tools, then
`run_harness <sandbox> <cwd> [env...]`, which sets `$out` and `$run_exit`.

Do not call `run_harness` inside `$( )` — the subshell discards `$run_exit`, and
the exit status is half of what these tests assert on.
