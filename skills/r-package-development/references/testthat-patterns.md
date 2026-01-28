# testthat Advanced Patterns

## Test Organization

### One Test File Per R File

```
R/
├── data-validation.R
├── calculations.R
└── plotting.R

tests/testthat/
├── test-data-validation.R
├── test-calculations.R
└── test-plotting.R
```

### Shared Setup

In `tests/testthat/helper.R` (auto-loaded):

```r
# Test data used across multiple test files
sample_df <- data.frame(
  id = 1:5,
  value = c(10, 20, 30, NA, 50)
)

# Helper functions for tests
expect_df_equal <- function(actual, expected) {
  expect_equal(
    as.data.frame(actual),
    as.data.frame(expected),
    ignore_attr = TRUE
  )
}
```

### Setup and Teardown

```r
test_that("function works with temp files", {
  # Setup - runs before test
  tmp <- tempfile()
  writeLines("test data", tmp)

  # Cleanup - runs after test (even if test fails)
  withr::defer(unlink(tmp))

  result <- read_my_file(tmp)
  expect_equal(result, "test data")
})
```

For setup/teardown across all tests in a file:

```r
setup({
  # Runs once before all tests in this file
  test_db <<- connect_test_database()
})

teardown({
  # Runs once after all tests in this file
  disconnect(test_db)
})
```

## Expectation Patterns

### Equality

```r
# Exact equality
expect_equal(result, expected)

# Numeric tolerance
expect_equal(result, expected, tolerance = 1e-6)

# Identical (including attributes)
expect_identical(result, expected)
```

### Errors and Warnings

```r
# Any error
expect_error(bad_function())

# Specific message pattern
expect_error(bad_function(), "must be numeric")

# Specific error class (recommended for rlang conditions)
expect_error(bad_function(), class = "my_error_class")

# Warnings
expect_warning(warn_function(), "deprecated")

# Messages
expect_message(verbose_function(), "Processing")

# No error/warning/message
expect_no_error(good_function())
expect_no_warning(quiet_function())
```

### Conditions

```r
# Check specific condition
expect_condition(
  my_function(bad_input),
  class = "mypackage_validation_error"
)

# Capture condition for inspection
cond <- expect_condition(my_function(bad_input))
expect_equal(cond$x, bad_input)
```

### Output

```r
# Printed output
expect_output(print(obj), "expected text")

# Silent (no output)
expect_silent(quiet_function())
```

### Type and Structure

```r
# Type checks
expect_type(result, "list")
expect_s3_class(result, "data.frame")
expect_s4_class(result, "MyS4Class")

# Length
expect_length(result, 5)

# Names
expect_named(result, c("a", "b", "c"))
expect_named(result)  # Just that it has names
```

### Comparisons

```r
expect_true(is_valid(x))
expect_false(is_empty(x))
expect_null(optional_result())
expect_gt(length(x), 0)
expect_gte(score, 0)
expect_lt(error, tolerance)
expect_lte(count, max_count)
```

## Snapshot Testing

### Text Snapshots

```r
test_that("summary output is stable", {
 obj <- create_complex_object()
 expect_snapshot(print(obj))
})

test_that("error messages are informative", {
 expect_snapshot(error = TRUE, {
   my_function(bad_input)
 })
})
```

### File Snapshots

```r
test_that("plot output is stable", {
 skip_on_ci()  # Plots can vary by platform

 path <- save_plot(create_plot(), tempfile(fileext = ".png"))
 expect_snapshot_file(path, name = "basic-plot.png")
})
```

### Snapshot Workflow

```bash
# Run tests - new snapshots created as _new.md
devtools::test()

# Review changes
# tests/testthat/_snaps/test-file/snapshot-name.md
# tests/testthat/_snaps/test-file/snapshot-name.new.md

# Accept changes
testthat::snapshot_accept()

# Or review interactively
testthat::snapshot_review()
```

## Skipping Tests

```r
# Skip on specific platforms
skip_on_cran()
skip_on_ci()
skip_on_os("windows")

# Skip if dependency missing
skip_if_not_installed("optional_package")

# Skip conditionally
skip_if(condition, message = "Reason for skipping")
skip_if_not(condition, message = "Reason for skipping")

# Skip offline tests
skip_if_offline()
```

## Testing with External Resources

### Mocking

```r
test_that("function handles API response", {
  # Mock the API call
  local_mocked_bindings(
    fetch_data = function(...) {
      list(status = "success", data = 1:5)
    }
  )

  result <- process_api_data()
  expect_equal(result$count, 5)
})
```

### Temporary Files

```r
test_that("function writes correctly", {
  withr::with_tempdir({
    write_output("test.txt", data)
    expect_true(file.exists("test.txt"))
    expect_equal(readLines("test.txt"), expected_lines)
  })
})
```

### Environment Variables

```r
test_that("function respects config", {
  withr::with_envvar(c(MY_CONFIG = "test_value"), {
    result <- read_config()
    expect_equal(result, "test_value")
  })
})
```

## Parameterized Tests

```r
test_that("function handles various inputs", {
  cases <- list(
    list(input = 1, expected = "one"),
    list(input = 2, expected = "two"),
    list(input = 3, expected = "three")
  )

  for (case in cases) {
    expect_equal(
      number_to_word(case$input),
      case$expected,
      info = paste("Input:", case$input)
    )
  }
})
```

## Debugging Tests

```r
# Run single test file
devtools::test_active_file()

# Run tests matching pattern
devtools::test(filter = "validation")

# Interactive debugging
test_that("debugging example", {
  browser()  # Drops into debugger
  result <- my_function()
  expect_true(result)
})
```
