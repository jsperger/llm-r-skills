# CHANGELOG
## [Unreleased]

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
