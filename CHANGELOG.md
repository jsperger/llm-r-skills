# CHANGELOG

## [0.2.0]

### Added

- **Skill**: `r-languageserver` - Guidance for navigating R code with the language server: finding definitions, references, and call hierarchies, and running impact analysis before refactoring. Helps Claude discover and operate LSP functionality that the plugin alone did not surface, and directs it to prefer semantic LSP navigation over text search (which false-matches names in comments, strings, and docstrings) for symbol lookups.
- **Command**: `/r-lsp-diagnose` - Diagnose R language server connectivity and configuration issues and suggest fixes.
- **Script**: `lsp-test-harness.sh` - Diagnostic harness (invoked by `/r-lsp-diagnose`) that exercises core LSP functionality and reports issues as JSON; supports `--fix`.

## [0.1.2]

- Baseline release: R programming skills packaged as a Claude Code plugin with `air` formatting hook and `languageserver` LSP support.
