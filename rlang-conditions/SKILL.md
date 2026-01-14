---
name: rlang-conditions
description: >
  Use when developing R packages that need to handle errors, warnings, and
  conditions properly. Covers: (1) cli_abort/cli_warn/cli_inform for throwing
  conditions with formatting, (2) Error call context with caller_env() and
  caller_arg(), (3) Input validation helpers that report the right function,
  (4) Error chaining with try_fetch() and parent argument,
  (5) Testing error conditions with testthat snapshots.
dependencies: R>=4.3, rlang>=1.1.3
---

# Condition Handling in R Packages

## When to Use What

| Task | Use |
|------|-----|
| Throw formatted error | `cli_abort()` with message and bullets |
| Throw formatted warning | `cli_warn()` with message and bullets |
| Display informative message | `cli_inform()` with message and bullets |
| Show correct function in error | `call = caller_env()` argument |
| Get argument name dynamically | `arg = caller_arg(x)` in input checkers |
| Catch and rethrow with context | `try_fetch()` with `parent = cnd` |
| Take ownership of low-level error | `try_fetch()` with `parent = NA` |
| Test error messages | `expect_snapshot(error = TRUE, ...)` |

## CLI Conditions Essentials

Use `cli_abort()`, `cli_warn()`, and `cli_inform()` instead of base R's `stop()`, `warning()`, and `message()` for formatted condition messages.

### Basic Usage

```r
# Simple error
cli_abort("Column {.field name} is required")

# Simple warning
cli_warn("Column {.field {col}} has missing values")

# Simple message
cli_inform("Processing {n} file{?s}")
```

### Structured Messages with Bullets

Use named character vectors for multi-part messages:

```r
cli_abort(c(

  "File not found",
  "x" = "Cannot read {.file {path}}",

  "i" = "Check that the file exists"
))
```

**Bullet types:**
- `"x"` - Error/problem (red X)
- `"!"` - Warning (yellow !)
- `"i"` - Information (blue i)
- `"v"` - Success (green checkmark)
- `"*"` - Bullet point
- `">"` - Arrow/pointer

### Essential Inline Markup

Format values in condition messages for clarity:

```r
# Arguments
cli_abort("{.arg x} must be numeric")

# Files and paths
cli_abort("Cannot find {.file {path}}")

# Values
cli_abort("Expected {.val TRUE}, got {.val {x}}")

# Classes/types
cli_abort("Expected numeric, got {.cls {class(x)}}")

# Code
cli_abort("Use {.code na.rm = TRUE} to ignore missing values
")

# Function names
cli_abort("See {.fn mypackage::helper} for details")
```

### Pluralization

Use `{?}` for automatic singular/plural handling:

```r
cli_abort("Found {n} error{?s}")
#> Found 1 error
#> Found 3 errors

cli_abort("Found {n} director{?y/ies}")
#> Found 1 directory
#> Found 5 directories
```

## Error Call Context

By default, `abort()` and `cli_abort()` show the function where they are called. When using error helpers, pass `call = caller_env()` to show the user's function instead.

### The Problem

```r
# Error helper without call context
stop_my_class <- function(message) {

  abort(message, class = "my_class")
}

my_function <- function(x) {
  stop_my_class("Something went wrong")
}

my_function("test")
#> Error in `stop_my_class()`:
#> ! Something went wrong
```
The error shows `stop_my_class()` but users called `my_function()`.

### The Solution

```r
stop_my_class <- function(message, call = caller_env()) {
  abort(message, class = "my_class", call = call)
}

my_function <- function(x) {
  stop_my_class("Something went wrong")
}

my_function("test")
#> Error in `my_function()`:
#> ! Something went wrong
```

Now the error correctly shows `my_function()`.

### Pattern: Abort Wrapper

```r
stop_my_class <- function(message, call = caller_env()) {
  abort(message, class = "my_class", call = call)
}
```

## Input Checkers

Input checkers validate function arguments. Use `caller_arg()` to get the argument name dynamically and `caller_env()` for proper error context.

### Basic Input Checker

```r
check_string <- function(x,
                         arg = caller_arg(x),
                         call = caller_env()) {
  if (!is_string(x)) {
    cli_abort("{.arg {arg}} must be a string.", call = call)
  }
}
```

### Using the Checker

```r
my_function <- function(my_arg) {
  check_string(my_arg)
  # ... rest of function
}

my_function(NA)
#> Error in `my_function()`:
#> ! `my_arg` must be a string.
```

The error shows:
- The correct function (`my_function`, not `check_string`)
- The correct argument name (`my_arg`, not `x`)

### Pattern: Complete Input Checker

```r
check_scalar_numeric <- function(x,
                                  arg = caller_arg(x),
                                  call = caller_env()) {
  if (!is.numeric(x) || length(x) != 1) {
    cli_abort(c(
      "{.arg {arg}} must be a single number",
      "x" = "You supplied {.cls {class(x)}} of length {length(x)}"
    ), call = call)
  }
}
```

### Built-in Checkers from rlang

rlang provides `check_required()` for mandatory arguments:

```r
my_function <- function(data) {
  check_required(data)
  # ... rest of function
}

my_function()
#> Error in `my_function()`:
#> ! `data` is absent but must be supplied.
```

## Error Chaining

Error chaining adds context when catching and rethrowing errors. Use `try_fetch()` to catch errors and `parent` to chain them.

### Basic Error Chaining

```r
with_chained_errors <- function(expr, call = caller_env()) {
  try_fetch(
    expr,
    error = function(cnd) {
      abort("Problem during step.", parent = cnd, call = call)
    }
  )
}

my_verb <- function(expr) {
  with_chained_errors(expr)
}

my_verb(1 + "a")
#> Error in `my_verb()`:
#> ! Problem during step.
#> Caused by error in `1 + "a"`:
#> ! non-numeric argument to binary operator
```

### Why try_fetch() Over tryCatch()

- Preserves full backtrace context for debugging
- Allows `options(error = recover)` to work
- Catches stack overflow errors (R >= 4.2.0)

### Taking Ownership of Errors

Use `parent = NA` to completely replace a low-level error:

```r
with_user_friendly_errors <- function(expr, call = caller_env()) {
  try_fetch(
    expr,
    vctrs_error_scalar_type = function(cnd) {
      abort(
        "Must supply a vector.",
        parent = NA,
        error = cnd,  # Store original for debugging
        call = call
      )
    }
  )
}
```

**For advanced error chaining patterns**: See [references/error-chaining.md](references/error-chaining.md) for iteration context, modifying error calls, and case studies.

## Testing Error Conditions

Use testthat snapshot tests to verify error messages.

### Basic Snapshot Test

```r
test_that("validation errors are clear", {
  expect_snapshot(error = TRUE, {
    my_function(NULL)
  })
})
```

This creates a snapshot file recording the exact error output.

### Testing Multiple Cases

```r
test_that("input validation catches bad inputs", {
  expect_snapshot(error = TRUE, {
    check_string(123)
    check_string(NA)
    check_string(c("a", "b"))
  })
})
```

### Enabling rlang Error Display

To see the `call` field in error snapshots, depend on rlang >= 1.0.0 in your package. With testthat >= 3.1.2, this enables the enhanced error display automatically.

### Testing Error Classes

```r
test_that("errors have correct class", {
  expect_error(
    validate_input(NULL),
    class = "validation_error"
  )
})
```

## Resources

### rlang Documentation
- [Error call documentation](https://rlang.r-lib.org/reference/topic-error-call.html)
- [Error chaining documentation](https://rlang.r-lib.org/reference/topic-error-chaining.html)
- [Condition customisation](https://rlang.r-lib.org/reference/topic-condition-customisation.html)

### cli Documentation
- [cli package](https://cli.r-lib.org/)
- [Semantic CLI article](https://cli.r-lib.org/articles/semantic-cli.html)

### Style Guide
- [Tidyverse error style guide](https://style.tidyverse.org/errors.html)

### Reference Files
- [references/error-chaining.md](references/error-chaining.md) - Advanced error chaining patterns
- [references/customisation.md](references/customisation.md) - Condition appearance customization
