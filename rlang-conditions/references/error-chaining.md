# Error Chaining Reference

Error chaining provides contextual information when errors occur. Chain errors to show high-level context, pipeline steps, or iteration state alongside the original error.

## Table of Contents

1. [Concepts](#concepts)
2. [try_fetch() Basics](#try_fetch-basics)
3. [Chaining Patterns](#chaining-patterns)
4. [Taking Ownership](#taking-ownership)
5. [Iteration Context](#iteration-context)
6. [Modifying Error Calls](#modifying-error-calls)

## Concepts

### Causal vs Contextual Errors

Error chains have two types of errors:

1. **Causal error** - The original error that interrupted execution
2. **Contextual error** - Higher-level information about what was happening

```r
#> Error in `my_verb()`:
#> ! Problem while processing data.
#> Caused by error in `1 + "a"`:
#> ! non-numeric argument to binary operator
```

Here:
- "Problem while processing data" is the **contextual error**
- "non-numeric argument to binary operator" is the **causal error**

### When to Chain Errors

Chain errors when you can provide useful context:

- **High-level context**: What operation was being attempted
- **Pipeline step**: Which step in a multi-step process failed
- **Iteration context**: Which element/file/iteration failed

## try_fetch() Basics

Use `try_fetch()` instead of `tryCatch()` or `withCallingHandlers()`:

```r
try_fetch(
  expr,
  error = function(cnd) {
    # Handle error
  }
)
```

### Why try_fetch()?

| Feature | try_fetch() | tryCatch() | withCallingHandlers() |
|---------|------------|------------|----------------------|
| Preserves backtrace | Yes | No | Yes |
| Catches stack overflow | Yes (R >= 4.2) | No | No |
| Works with recover | Yes | No | Yes |

### Basic try_fetch() Usage

```r
result <- try_fetch(
  risky_operation(),
  error = function(cnd) {
    # cnd is the error condition object
    # Return a value or rethrow
    NULL
  }
)
```

## Chaining Patterns

### Pattern 1: Simple Context

```r
with_context <- function(expr, context, call = caller_env()) {
  try_fetch(
    expr,
    error = function(cnd) {
      abort(context, parent = cnd, call = call)
    }
  )
}

load_data <- function(path) {
  with_context(
    read.csv(path),
    sprintf("Failed to load data from '%s'", path)
  )
}
```

### Pattern 2: With Helper Function

Create reusable error context helpers:

```r
with_step_context <- function(expr, step_name, call = caller_env()) {
  try_fetch(
    expr,
    error = function(cnd) {
      cli_abort(
        c("Problem during {.field {step_name}} step."),
        parent = cnd,
        call = call
      )
    }
  )
}

process_pipeline <- function(data) {
  data <- with_step_context(clean(data), "cleaning")
  data <- with_step_context(transform(data), "transformation")
  data <- with_step_context(validate(data), "validation")
  data
}
```

### Pattern 3: User-Facing Verb

```r
my_verb <- function(expr) {
  check_required(expr)  # Check required args BEFORE error context
  with_chained_errors(expr)
}

with_chained_errors <- function(expr, call = caller_env()) {
  try_fetch(
    expr,
    error = function(cnd) {
      abort("Problem during step.", parent = cnd, call = call)
    }
  )
}
```

**Important**: Check required arguments before setting up error context to avoid confusing error chains for missing arguments.

## Taking Ownership

Sometimes you want to completely replace a low-level error with a user-friendly message. Use `parent = NA`:

```r
with_friendly_errors <- function(expr, call = caller_env()) {
  try_fetch(
    expr,
    vctrs_error_scalar_type = function(cnd) {
      abort(
        "Must supply a vector.",
        parent = NA,       # Don't chain - replace entirely
        error = cnd,       # Store original for debugging
        call = call
      )
    }
  )
}
```

### When to Take Ownership

- **Do**: Replace low-level technical errors (HTTP, vctrs internal)
- **Don't**: Hide user errors (wrong input types, etc.)
- **Don't**: Replace errors indiscriminately

### Accessing the Original Error

Store the original error for debugging:

```r
# Throw with stored error
abort("User-friendly message", parent = NA, error = original_cnd)

# Later, access it
rlang::last_error()$error
```

## Iteration Context

Add iteration information when processing multiple items:

### Basic Pattern

```r
my_map <- function(.xs, .fn, ...) {
  out <- vector("list", length(.xs))
  i <- 0L

  try_fetch(
    for (i in seq_along(.xs)) {
      out[[i]] <- .fn(.xs[[i]], ...)
    },
    error = function(cnd) {
      abort(
        sprintf("Problem while mapping element %d.", i),
        parent = cnd
      )
    }
  )

  out
}

list(1, "foo") |> my_map(\(x) x + 1)
#> Error:
#> ! Problem while mapping element 2.
#> Caused by error in `x + 1`:
#> ! non-numeric argument to binary operator
```

### Performance Note

Place `try_fetch()` **outside** the loop. Wrapping each iteration is expensive:

```r
# Good - try_fetch outside loop
try_fetch(
  for (i in seq_along(xs)) { ... },
  error = function(cnd) { ... }
)

# Bad - try_fetch inside loop (slow!)
for (i in seq_along(xs)) {
  try_fetch(
    process(xs[[i]]),
    error = function(cnd) { ... }
  )
}
```

### Named Elements

For named lists, include the name:

```r
my_map <- function(.xs, .fn, ...) {
  nms <- names(.xs) %||% seq_along(.xs)
  out <- vector("list", length(.xs))
  i <- 0L

  try_fetch(
    for (i in seq_along(.xs)) {
      out[[i]] <- .fn(.xs[[i]], ...)
    },
    error = function(cnd) {
      abort(
        sprintf("Problem while mapping element `%s`.", nms[[i]]),
        parent = cnd
      )
    }
  )

  out
}
```

## Modifying Error Calls

Sometimes the error call shows an internal function name. You can modify it:

### The Problem

```r
my_map <- function(.xs, .fn, ...) {
  for (i in seq_along(.xs)) {
    out[[i]] <- .fn(.xs[[i]], ...)  # Error shows `.fn()`
  }
}

my_function <- function(x) {
  if (!is_string(x)) abort("`x` must be a string.")
}

list(1) |> my_map(my_function)
#> Error in `.fn()`:
#> ! `x` must be a string.
```

Users see `.fn()` but they passed `my_function`.

### The Solution

Inspect and modify the error's `call` field:

```r
my_map <- function(.xs, .fn, ...) {
  fn_code <- substitute(.fn)  # Capture the expression passed as .fn
  out <- vector("list", length(.xs))

  for (i in seq_along(.xs)) {
    try_fetch(
      out[[i]] <- .fn(.xs[[i]], ...),
      error = function(cnd) {
        # If error call starts with .fn, replace with actual function
        if (is_call(cnd$call, ".fn")) {
          cnd$call[[1]] <- fn_code
        }
        abort(
          sprintf("Problem while mapping element %d.", i),
          parent = cnd
        )
      }
    )
  }

  out
}

list(1) |> my_map(my_function)
#> Error:
#> ! Problem while mapping element 1.
#> Caused by error in `my_function()`:
#> ! `x` must be a string.
```

Now the error shows `my_function()` instead of `.fn()`.
