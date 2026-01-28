---
description: Diagnose R language server issues and suggest fixes
allowed-tools: Read, Bash, Grep
---

Test the R Language Server Protocol (LSP) setup and diagnose issues.

Run the diagnostic harness: !`"$CLAUDE_PLUGIN_ROOT"/scripts/lsp-test-harness.sh`

Based on the results:

**If all tests pass:**
- Confirm LSP should be functional
- Suggest restarting Claude Code session if issues persist
- Check if .lsp.json settings are appropriate for the project

**If tests fail:**

For each failed test, explain:
1. What the test checks
2. Why it might have failed
3. How to fix it

Common fixes:

**languageserver not installed:**
```r
install.packages("languageserver")
```

**lintr not installed (affects diagnostics):**
```r
install.packages("lintr")
```

**R not in PATH:**
- Check R installation
- Ensure R is accessible from terminal
- May need to add R to PATH in shell profile

**air formatter not installed:**
- Install from https://github.com/posit-dev/air
- Or use `cargo install air-r` if Rust is available

**LSP configuration issues:**
- Check .lsp.json for valid JSON syntax
- Verify languageserver settings are correct

If user confirms fixes should be attempted, run: !`"$CLAUDE_PLUGIN_ROOT"/scripts/lsp-test-harness.sh --fix`

After any fixes, suggest restarting Claude Code to reload the LSP.
