# llm-r-skills

Claude Code plugin for R development. `main` is protected — never commit there directly.

## R templates

Use `UPPERCASE` placeholder names in `.R` template files (e.g. `STEPNAME`, `ACTIONDESC`),
not `{{placeholder}}`. The `air` formatter treats `{{` as glue/curly-curly syntax and
rewrites it, breaking the templates.

## Shell scripts

Bash is required. The lowest supported version is 3.2.57, which ships as macOS
`/bin/bash` and is what `#!/bin/bash` selects there.

- Run `shellcheck <script>` after writing or changing any `.sh` file. Resolve every
  finding before committing.
- Under `set -u`, bash 3.2 treats `"${arr[@]}"` on an *empty* array as an unbound
  variable. Use `${arr[@]+"${arr[@]}"}`.
- Assume no `timeout` — macOS ships neither it nor `gtimeout`. Detect, or run without.
- Assume no `jq`. Check `command -v jq` at the top of any script that uses it.
- Diagnostic scripts must always print non-empty JSON and exit 0, especially when the
  environment is broken. `set -euo pipefail` fights this: a command substitution in an
  assignment propagates its exit status, and an unset var aborts even inside `[[ ]]`
  with stderr redirected.

## Commands

`` !`cmd` `` in a command's `.md` runs unconditionally at prompt expansion, before the
model sees it. Never put a side-effecting or conditional command there — "if the user
confirms…" is prose the shell never reads. Have the model run it via Bash instead.

## Testing

`tests/diagnostics/test-lsp-harness.sh` covers the shell tooling. Run it after touching
any script it covers.

A regression test that also passes against the pre-fix code proves nothing. Check:
`LSP_HARNESS=/tmp/old.sh tests/diagnostics/test-lsp-harness.sh`.
