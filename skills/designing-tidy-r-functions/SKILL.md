---
name: designing-tidy-r-functions
description: >
  Use when designing R function APIs, reviewing R code for design issues,
  writing functions for R packages, or evaluating argument ordering and
  naming decisions. Does NOT cover: style/linting, error handling
  (rlang-conditions), CLI output (r-lib:cli), testing (testing-r-packages),
  CRAN compliance (cran-extrachecks).
---

# Tidy R Function Design

Design R functions for humans, not computers. Optimize for cognitive load reduction, predictability, and composability. These principles apply to any R code, not just tidyverse packages.

**Core principle:** The less a user needs to think to use your function correctly, the better.

## Quick Reference

| Design Goal | Pattern |
|-------------|---------|
| Predictable names | Verb in imperative mood, prefixes for families |
| Clear arguments | Most important first, optional with defaults last |
| Pipe-friendly | Primary data as first argument |
| Type stability | Output type predictable from input types |
| Enumerated options | Use `arg_match()` with character vector defaults |
| Side effects | Return input invisibly; partition from computation |
| Complex strategies | Extract to strategy objects (not boolean flags) |

## Function Naming

### Use Verbs in Imperative Mood

```r
# Good: imperative verbs
mutate()
filter()
summarize()

# Exception: noun-y builders
geom_point()
recipe()
```

### Prefer Prefixes Over Suffixes

Prefixes enable autocomplete discovery:

```r
# Good: common prefix groups related functions
str_detect(), str_replace(), str_extract()
read_csv(), read_tsv(), read_delim()

# Suffixes for variations on a theme
map_int(), map_chr(), map_dbl()
```

### Length Inversely Proportional to Frequency

```r
# Very frequent -> short
c(), n(), df

# Less frequent -> descriptive
create_bootstrap_samples()
validate_model_specification()
```

## Argument Design

### Most Important Arguments First

```r
# Good: transformed data first (pipe-friendly)
str_replace(string, pattern, replacement)
left_join(x, y, by)

# Output-determining args early
read_csv(file, col_types, col_names)
```

### Required Arguments Have No Defaults

```r
# Good: required args have no defaults
my_function <- function(data, columns, method = "default") {
  # data and columns required, method optional
}

# Bad: everything has defaults
my_function <- function(data = NULL, columns = NULL, method = "default")
```

### Dots Position Matters

Place `...` between required and optional arguments:

```r
# Good: forces explicit naming of optional args
my_function <- function(x, y, ..., verbose = FALSE, na.rm = TRUE) {
  # x, y required; anything after ... must be named
}
```

### Keep Defaults Short

Use `NULL` for complex defaults, compute in body:

```r
# Good: NULL signals "computed if not provided"
my_function <- function(x, weights = NULL) {
  weights <- weights %||% rep(1, length(x))
}

# Bad: complex default in signature
my_function <- function(x, weights = rep(1, length(x)))
```

### Enumerate String Options

Use `arg_match()` with character vector defaults:

```r
my_function <- function(x, method = c("fast", "accurate", "balanced")) {
  method <- rlang::arg_match(method)
  # method is now validated, first value is default
}
```

### Standardize Common Argument Names

| Purpose | Use | Not |
|---------|-----|-----|
| New data for prediction | `new_data` | `newdata`, `newData` |
| Missing value handling | `na_rm` | `na.rm`, `rm.na` |
| Case weights | `weights` | `wts`, `w` |
| Predictors (data frame) | `x` | `predictors`, `features` |
| Outcome (data frame) | `y` | `response`, `target` |
| Formula interface data | `data` | `df`, `dataset` |

## Output Patterns

### Type Stability

Output type should be predictable from input types, not values:

```r
# Bad: type depends on VALUE
ifelse(TRUE, 1L, 2)   # returns integer
ifelse(FALSE, 1L, 2)  # returns double

# Good: type predictable from input types
dplyr::if_else(TRUE, 1L, 2L)   # always integer
dplyr::if_else(FALSE, 1L, 2L)  # always integer
```

### Tibble Predictions

For modeling functions, predictions should return tibbles:
- Same number of rows as input
- Same row order as input
- Standardized column names: `.pred`, `.pred_class`, `.pred_lower`

```r
# Good prediction output
predict(model, new_data)
#> # A tibble: 100 x 1
#>     .pred
#>     <dbl>
#>  1   3.45
#>  2   2.89
```

### Side-Effect Functions Return Invisibly

Functions called for side effects should return the first argument invisibly:

```r
# Good: enables piping
write_csv <- function(x, file, ...) {
  # write the file
  invisible(x)
}

# Enables this pattern:
data |>
  write_csv("backup.csv") |>
  filter(important) |>
  write_csv("filtered.csv")
```

## Side Effects

### Partition Side Effects from Computation

```r
# Bad: computation mixed with side effects
analyze <- function(x) {
  result <- expensive_computation(x)
  cat("Computed result:", result, "\n")  # side effect buried
  options(my_option = result)            # hidden state change
  result
}

# Good: side effects isolated
analyze <- function(x, verbose = FALSE) {
  result <- expensive_computation(x)
  if (verbose) cli::cli_inform("Computed result: {result}")
  result
}
```

### Make Side Effects Easy to Undo

Functions that change global state should return previous values:

```r
# Good: returns previous value for restoration
old <- options(digits = 3)
# ... do work ...
options(old)  # restore
```

## Strategy Patterns

### Avoid Boolean Strategy Flags

```r
# Bad: boolean flags for strategies
grepl(pattern, x, perl = TRUE, fixed = FALSE, ignore.case = TRUE)
# Which combinations are valid? What does perl + fixed mean?

# Good: strategy objects
str_detect(x, regex(pattern, ignore_case = TRUE))
str_detect(x, fixed(pattern))
```

### Strategy Objects for Complex Options

When strategies need different arguments, create helper functions:

```r
# Strategy helpers with strategy-specific arguments
regex <- function(pattern, ignore_case = FALSE, multiline = FALSE) {
  structure(list(pattern = pattern, ignore_case = ignore_case,
                 multiline = multiline), class = "regex")
}

fixed <- function(pattern) {
  structure(list(pattern = pattern), class = "fixed")
}

# Main function accepts strategy objects
str_detect <- function(string, pattern) {
  if (inherits(pattern, "regex")) {
    # regex-specific handling
  } else if (inherits(pattern, "fixed")) {
    # fixed-specific handling
  }
}
```

## Explicit Over Implicit

### Avoid Global Option Dependencies

```r
# Bad: behavior depends on global option
my_function <- function(x) {
  na_action <- getOption("na.action")  # implicit input
  # ...
}

# Good: explicit argument with informative default
my_function <- function(x, na_action = na.omit) {
  # ...
}
```

### Inform Users of Important Defaults

When defaults matter, tell the user:

```r
my_function <- function(x, tz = Sys.timezone()) {
  if (missing(tz)) {
    cli::cli_inform("Using timezone: {.val {tz}}")
  }
  # ...
}
```

## Model Object Design

### Minimize Stored Data

```r
# Bad: stores entire training set
model$training_data <- training_set  # memory bloat

# Good: store only what's needed for prediction
model$coefficients <- coefs
model$levels <- factor_levels
```

### Never Save Call Objects

Call objects can embed entire datasets and environments:

```r
# Bad: call may contain data
model$call <- match.call()

# Good: omit call or store only essential info
```

### Use Proper S3 Constructors

```r
# Constructor (internal)
new_my_model <- function(coefficients, levels) {
  structure(
    list(coefficients = coefficients, levels = levels),
    class = "my_model"
  )
}

# Validator (internal)
validate_my_model <- function(x) {
  stopifnot(is.numeric(x$coefficients))
  x
}

# Helper (user-facing)
my_model <- function(...) {
  result <- new_my_model(...)
  validate_my_model(result)
}
```

### Matrix Subsetting Discipline

Always preserve matrix structure:

```r
# Bad: may return vector
X[, 1]

# Good: always returns matrix
X[, 1, drop = FALSE]
```

## Design Review Checklist

When reviewing R function design:

- [ ] Function names are verbs in imperative mood (or nouns for builders)
- [ ] Related functions share a prefix
- [ ] Most important arguments come first
- [ ] Primary data is first argument (pipe-friendly)
- [ ] Required arguments have no defaults
- [ ] `...` comes between required and optional arguments
- [ ] String options use `arg_match()` with enumerated defaults
- [ ] Output type is predictable from input types
- [ ] Side-effect functions return input invisibly
- [ ] No hidden dependencies on global options or locale
- [ ] Strategy variations use objects, not boolean flags
- [ ] Model objects don't store training data or calls
- [ ] Matrix subsetting uses `drop = FALSE`

## Resources

- [Tidy Design Principles](https://design.tidyverse.org)
- [Tidymodels Implementation Principles](https://tidymodels.github.io/model-implementation-principles/)
- [Advanced R: S3](https://adv-r.hadley.nz/s3.html)
