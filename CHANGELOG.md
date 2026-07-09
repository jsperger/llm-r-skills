# CHANGELOG

## [0.3.0]

### Added

- **Agent lint profile**: `config/agent.lintr` - a correctness-only linter set
  (object usage, missing packages, `== NA`, `T`/`F` symbols, and similar) applied
  automatically when the project has no `.lintr`/`.lintr.R` of its own. Style-severity
  lints are dropped: the `air` hook already fixes style after every edit, so they only
  added diagnostic noise to sessions. A project's own lintr config always wins.
- **LSP startup profile**: `config/agent.Rprofile`, delivered via `.lsp.json`
  `env.R_PROFILE_USER` - wires up the agent lint profile, sources the user's real
  `~/.Rprofile`, and disables the server's styler formatting capabilities (synchronous,
  blocks the event loop, and would fight the `air` hook).
- **LSP settings**: `.lsp.json` now enables `lint_cache` and a 15 s
  `diagnostics_cache_ttl`.

### Fixed

- The agent lint profile now actually reaches the subprocess where linting runs.
  languageserver lints in callr child processes, and callr rewrites `R_PROFILE_USER`
  there, so locating `agent.lintr` relative to that env var silently fell back to
  lintr's default (noisy) linters in real sessions. The profile now self-locates via
  `CLAUDE_PLUGIN_ROOT`, with `R_PROFILE_USER` as the fallback for non-Claude launches.
  Verified against live wire-tapped Claude Code sessions.

## [0.2.0]

### Added

- **Skill**: `r-languageserver` - Guidance for navigating R code with the language server: finding definitions, references, and call hierarchies, and running impact analysis before refactoring. Helps Claude discover and operate LSP functionality that the plugin alone did not surface, and directs it to prefer semantic LSP navigation over text search (which false-matches names in comments, strings, and docstrings) for symbol lookups.
- **Command**: `/r-lsp-diagnose` - Diagnose R language server connectivity and configuration issues and suggest fixes.
- **Script**: `lsp-test-harness.sh` - Diagnostic harness (invoked by `/r-lsp-diagnose`) that exercises core LSP functionality and reports issues as JSON; supports `--fix`.
- **Tests**: `tests/diagnostics/` - Deterministic tests for the shipped shell tooling, covering degraded environments (missing `jq`, `R`, `timeout`) that cannot be reproduced on a healthy machine. See `tests/diagnostics/README.md`.

### Fixed

- `lsp-test-harness.sh` no longer aborts before emitting JSON when `jq` is missing, when `CLAUDE_PROJECT_DIR` is unset (i.e. any invocation outside a Claude session), or on bash 3.2, which is what `/bin/bash` resolves to on macOS.
- `lsp-test-harness.sh` no longer reports "languageserver package not installed" on machines with no R at all, and no longer advises `install.packages()` where there is no R to run it in.
- The LSP startup check now falls back to `gtimeout`, or to no timeout, instead of reporting a spurious startup failure on macOS, which ships neither `timeout` nor `gtimeout`.
- `/r-lsp-diagnose` no longer runs `lsp-test-harness.sh --fix` unconditionally. The `` !`...` `` form expands before the model sees the prompt, so the "if user confirms" guard was prose the shell never read, and every invocation attempted CRAN installs.

## [0.1.2]

- Baseline release: R programming skills packaged as a Claude Code plugin with `air` formatting hook and `languageserver` LSP support.
