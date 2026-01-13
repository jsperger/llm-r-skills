---
name: creating-targetopia-packages
description: >
  Use when creating an R package that extends the targets workflow framework,
  building target factories for domain-specific pipelines, or implementing
  static/dynamic branching patterns for targets. Covers: tar_target_raw(),
  metaprogramming for factories, batching, testing pipelines.
---

# Creating R Targetopia Packages

R Targetopia packages extend the [`targets`](https://docs.ropensci.org/targets) workflow framework for specific domains. They use **target factories** - functions that generate lists of pre-configured targets from simple user inputs.

## Quick Reference

| Task | Function/Pattern |
|------|------------------|
| Create target in factory | `tar_target_raw(name, command, ...)` |
| Quote an expression | `quote(f(x))` |
| Expression to string | `deparse(quote(f(x)))` |
| Insert values into expression | `substitute(f(arg), env = list(arg = value))` |
| String to symbol | `as.symbol("name")` |
| Static branching | `tarchetypes::tar_map()` |
| Dynamic branching | `pattern` argument + batching |
| Test in temp directory | `targets::tar_test()` |
| Check pipeline structure | `tar_manifest()`, `tar_network()` |

## Target Factory Pattern

A target factory accepts simple inputs and returns a list of configured targets:

```r
#' @export
target_factory <- function(name, file) {
  # Build target names from user input
 name_model <- deparse(substitute(name))
  name_file <- paste0(name_model, "_file")
  name_data <- paste0(name_model, "_data")

 # Create symbols for cross-target references
  sym_file <- as.symbol(name_file)
  sym_data <- as.symbol(name_data)

 # Build commands with substitute()
  command_data <- substitute(read_data(file), env = list(file = sym_file))
  command_model <- substitute(run_model(data), env = list(data = sym_data))

 list(
    tar_target_raw(name_file, file, format = "file", deployment = "main"),
    tar_target_raw(name_data, command_data, format = "fst_tbl"),
    tar_target_raw(name_model, command_model, format = "qs")
  )
}
```

User writes one call instead of multiple `tar_target()` calls:

```r
# _targets.R
library(targets)
library(yourPackage)
target_factory(custom, "data.csv")
```

## tar_target_raw() vs tar_target()

| Aspect | `tar_target()` | `tar_target_raw()` |
|--------|----------------|-------------------|
| Audience | End users | Package developers |
| Name argument | Symbol | Character string |
| Command argument | Expression | Quoted expression |
| Pattern argument | Expression | Quoted expression |

## Metaprogramming Essentials

### quote() - Capture Expression

```r
quote(f(x + y))
#> f(x + y)
```

### deparse() - Expression to String

```r
deparse(quote(f(x + y)))
#> [1] "f(x + y)"
```

### substitute() - Insert Values

```r
substitute(f(arg = arg), env = list(arg = quote(x + y)))
#> f(arg = x + y)
```

Inside a function, `env` defaults to the calling environment:

```r
f <- function(arg) substitute(f(arg = arg))
f(x + y)
#> f(arg = x + y)
```

### as.symbol() - String to Symbol

```r
as.symbol("my_target")
#> my_target
```

## Optimal Settings

Pre-configure arguments users shouldn't worry about:

| Setting | When to Use |
|---------|-------------|
| `deployment = "main"` | File targets (local files can't run on remote workers) |
| `format = "file"` | Track input files, invalidate when contents change |
| `format = "fst_tbl"` | Efficient data frame storage |
| `format = "qs"` | Efficient general-purpose storage |

Expose arguments users may need (`priority`, `cue`). Hide low-level arguments (`deps`, `string`).

## Branching

### Static Branching

For small numbers of heterogeneous tasks. Use `tarchetypes::tar_map()`:

```r
# Internally map over Stan model files
tar_stan_mcmc <- function(stan_files, ...) {
  tarchetypes::tar_map(
    values = list(stan_file = stan_files),
    tar_target_raw(...)
  )
}
```

### Dynamic Branching

For large homogeneous tasks. Generate `pattern` argument programmatically and support batching:

```r
my_factory <- function(name, batches = 1, reps = 1, ...) {
  # Users control batches/reps, NOT pattern
  # See tar_rep_raw(), tar_stan_mcmc_rep_summary() for examples
}
```

## Testing

### What to Test

1. **Results**: Run pipeline, check outputs
2. **Manifest**: Verify target count, commands, settings
3. **Dependencies**: Check graph edges between targets

### tar_test() Pattern

```r
tar_test("factory creates correct targets", {
  # Runs in temp directory, resets options after
  targets <- target_factory(test, "data.csv")
  expect_length(targets, 3)
  expect_equal(targets[[1]]$settings$name, "test_file")
})
```

### Speed Tips

- Use `callr_function = NULL` in `tar_make()` for faster tests (but sensitive to test environment)
- Use `testthat::skip_on_cran()` for slow tests

## Documentation

### Examples

Keep `@examples` fast and avoid non-temporary files. Use `tar_dir()` for runnable examples:

```r
#' @examples
#' targets::tar_dir({
#'   targets::tar_script(target_factory(example, "data.csv"))
#'   targets::tar_make()
#' })
```

### README Badge

```md
[![R Targetopia](https://img.shields.io/badge/R_Targetopia-member-blue?style=flat&labelColor=gray)](https://wlandau.github.io/targetopia/)
```

## See Also

- **r-metaprogramming**: Expression manipulation fundamentals
- **designing-tidy-r-functions**: Function API design
- **testing-r-packages**: Testing patterns

## Reference Files

- [targetopia.Rmd](targetopia.Rmd) - Complete guide with full examples

## External Resources

- [targets documentation](https://docs.ropensci.org/targets)
- [tarchetypes package](https://docs.ropensci.org/tarchetypes)
- [stantargets](https://docs.ropensci.org/stantargets) - Example Targetopia package
- [rOpenSci software review](https://devguide.ropensci.org/softwarereviewintro.html)
