---
description: Add testthat tests for an R function or file
argument-hint: [file-or-function]
allowed-tools: Read, Write, Edit, Grep, Glob
---

Create comprehensive testthat tests for the specified R code.

Target: $ARGUMENTS

1. **Locate the source**:
   - If a file path is given, read that file: @$1
   - If a function name is given, search for it in the R/ directory

2. **Analyze the code** to identify:
   - Function inputs and expected types
   - Return values and their structure
   - Edge cases (NULL, empty, NA, wrong types)
   - Error conditions that should be handled
   - Side effects (if any)

3. **Find or create the test file**:
   - Look in tests/testthat/ for existing test-*.R file for this module
   - Create a new test file if none exists: tests/testthat/test-{module-name}.R

4. **Write tests** following testthat 3 patterns:

```r
describe("function_name()", {
  it("handles typical input correctly", {
    result <- function_name(typical_input)
    expect_equal(result, expected_output)
  })

  it("returns NULL for empty input", {
    expect_null(function_name(character(0)))
  })

  it("errors on invalid input", {
    expect_error(function_name(invalid), "error message pattern")
  })
})
```

5. **Run the new tests** to verify they pass (or identify bugs in the source)

Use the r-package-development skill for testthat patterns and best practices.

Report:
- What tests were added
- Any bugs discovered during test writing
- Coverage of edge cases
