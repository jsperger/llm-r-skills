# CHANGELOG

## []

## [0.3.0] - 2026-01-28

### Added

- **Commands**: New slash commands for R package development
  - `/r-fix-tests` - Diagnose and fix failing R package tests
  - `/r-add-tests` - Add testthat tests for a function or file
  - `/r-lsp-diagnose` - Test LSP connectivity and diagnose issues

- **Agents**: Autonomous agents for package development
  - `test-fixer` - Diagnoses and fixes failing tests
  - `roxygen-documenter` - Writes roxygen2 documentation for functions

- **Skill**: `r-package-development` - Comprehensive guide to devtools workflows, testthat 3 patterns, roxygen2 tags, usethis helpers, and monorepo organization

- **Scripts**: New utility scripts
  - `detect-package-root.sh` - Find R package root from file path
  - `detect-changed-packages.sh` - Identify packages with uncommitted changes
  - `r-pre-commit.sh` - Pre-commit workflow (format, document, test)
  - `lsp-test-harness.sh` - Diagnose LSP issues

### Changed

- **Pre-commit hook**: Now runs a full workflow before `git commit` and `gh pr create`:
  1. Format R files with `air`
  2. Run `devtools::document()` on packages with R/ changes
  3. Run `devtools::test()` on affected packages
  - Commits: warn on test failures (allow to proceed)
  - PRs: block if tests fail

- **Plugin manifest**: Added proper `plugin.json` alongside `marketplace.json`

## [0.2.0] - 2026-01-27

### Added

- Added the "r-languageserver" skill with instructions on using the LSP. I'd found that Claude did not seem aware of the LSP functionality from the plugin alone. 

- A hook to run `lintr::lint` after editing an R file. The hook passes the argument `parse_settings = TRUE` explicitly due a breaking change in `lintr` [v3.3.0-1](https://github.com/r-lib/lintr/releases/tag/v3.3.0-1) 

## Changed

- The `air` hook now only runs on the file that was edited  instead of the whole directory.

- The R language server is now called with a setting that disables `lintr` diagnostics (`r.lsp.diagnostics": false`). `lintr` changed its default settings and now `languageserver` [produces lints that don't respect the user's `.lintr` configuration ](https://github.com/REditorSupport/languageserver/pull/706).



## [0.1.2]

### Added
- Hook to run the `air` formatter

## [0.1.1]

### Added
- Support for R `languageserver` LSP

## [0.1.0]
- Wrap skills up as a plugin.
