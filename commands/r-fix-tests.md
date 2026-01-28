---
description: Diagnose and fix failing R package tests
argument-hint: [package-path]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Run the test suite and diagnose failures for the R package.

First, determine the package location:
- If $ARGUMENTS is provided, use that path
- Otherwise, detect the package root from the current working directory

Run the tests: !`Rscript -e "devtools::test('${1:-.}', reporter = 'summary')"`

For each failing test:

1. **Read the test file** to understand what's being tested
2. **Read the source file** being tested (typically in R/ directory)
3. **Analyze the failure**:
   - Is it a logic error in the source code?
   - Is the test expectation incorrect?
   - Is there a missing dependency or setup?
   - Is it a snapshot that needs updating?

4. **Fix the issue**:
   - Prefer fixing the source code if there's a bug
   - Update test expectations only if the new behavior is intentional
   - For snapshot tests, regenerate with `testthat::snapshot_accept()` if appropriate

5. **Re-run tests** to verify the fix

Use the r-package-development skill for testthat patterns and best practices.

Report what was fixed and why.
