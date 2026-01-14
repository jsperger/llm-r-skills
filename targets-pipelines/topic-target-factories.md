# Writing Custom Target Factory Functions

A target factory is a function that accepts simple inputs and returns a list of pre-configured target objects. Use factories to encapsulate reusable multi-target patterns with domain-specific defaults.

## When to Write a Factory

- **Repeated pattern**: Same multi-step workflow appears across projects
- **Domain encapsulation**: Hide complexity from pipeline authors
- **Consistent configuration**: Enforce format, storage, and deployment settings
- **Package distribution**: Share patterns via R packages

## Core Pattern

```r
#' Analyze a dataset with preprocessing and modeling
#'
#' @param name Symbol. Base name for generated targets.
#' @param file Character. Path to input data file.
#' @param model_fn Symbol. Modeling function to apply.
#' @export
analyze_dataset <- function(name, file, model_fn = fit_default) {
  # 1. Convert symbol arguments to strings
 name <- targets::tar_deparse_language(substitute(name))
  model_fn <- targets::tar_deparse_language(substitute(model_fn))

  # 2. Build derived target names
  name_file <- paste0(name, "_file")
  name_data <- paste0(name, "_data")
  name_model <- paste0(name, "_model")

  # 3. Create symbols for cross-target references
  sym_data <- as.symbol(name_data)
  sym_model_fn <- as.symbol(model_fn)

  # 4. Build commands with substitute()
  command_data <- substitute(
    preprocess(readr::read_csv(file)),
    env = list(file = file)
  )
  command_model <- substitute(
    model_fn(data),
    env = list(model_fn = sym_model_fn, data = sym_data)
  )

  # 5. Return list of target objects
  list(
    targets::tar_target_raw(
      name = name_file,
      command = quote(file),
      format = "file",
      deployment = "main"
    ),
    targets::tar_target_raw(
      name = name_data,
      command = command_data,
      format = "qs"
    ),
    targets::tar_target_raw(
      name = name_model,
      command = command_model,
      format = "qs"
    )
  )
}
```

**Usage in `_targets.R`:**

```r
list(
  analyze_dataset(sales, "data/sales.csv", model_fn = fit_xgboost),
  analyze_dataset(customers, "data/customers.csv")
)
```

## tar_target_raw() vs tar_target()

| Aspect | `tar_target()` | `tar_target_raw()` |
|--------|----------------|-------------------|
| Audience | End users | Factory authors |
| Name | Symbol: `tar_target(foo, ...)` | String: `tar_target_raw("foo", ...)` |
| Command | Expression: `tar_target(x, f(y))` | Quoted: `tar_target_raw("x", quote(f(y)))` |
| Pattern | Expression: `pattern = map(x)` | Quoted: `pattern = quote(map(x))` |

**Key rule:** Use `tar_target_raw()` in factories because you're programmatically constructing names and commands.

## Metaprogramming Essentials

### Capturing User Input

```r
# User writes: my_factory(analysis, data_file = "data.csv")
# Factory sees: substitute(name) -> quote(analysis)

my_factory <- function(name, data_file) {
  # Convert symbol to string
  name_str <- targets::tar_deparse_language(substitute(name))
  # Result: "analysis"
}
```

### Base R Metaprogramming

| Function | Purpose | Example |
|----------|---------|---------|
| `quote(expr)` | Capture expression literally | `quote(f(x + y))` → `f(x + y)` |
| `substitute(expr, env)` | Replace symbols in expression | `substitute(f(x), list(x = quote(y)))` → `f(y)` |
| `deparse(expr)` | Expression to string | `deparse(quote(foo))` → `"foo"` |
| `as.symbol(str)` | String to symbol | `as.symbol("foo")` → `foo` |
| `bquote(expr)` | Quote with `.()` splicing | `bquote(f(.(x)))` with `x <- quote(y)` → `f(y)` |

### Building Commands with substitute()

```r
# Pattern: substitute(template, env = list(placeholder = value))

# Simple substitution
substitute(analyze(data), env = list(data = as.symbol("my_data")))
#> analyze(my_data)

# Multiple substitutions
substitute(
  model_fn(data, params),
  env = list(
    model_fn = as.symbol("fit_glm"),
    data = as.symbol("clean_data"),
    params = quote(list(family = "binomial"))
  )
)
#> fit_glm(clean_data, list(family = "binomial"))
```

### Building Commands with bquote()

`bquote()` uses `.(expr)` for splicing (more readable for complex expressions):

```r
data_sym <- as.symbol("my_data")
model_sym <- as.symbol("fit_glm")

bquote(.(model_sym)(.(data_sym), family = "binomial"))
#> fit_glm(my_data, family = "binomial")
```

## Input Validation

Use `targets::tar_assert_*()` functions for consistent error messages:
```r
my_factory <- function(name, file, n_folds = 5) {
  name <- targets::tar_deparse_language(substitute(name))

  # Validate inputs
  targets::tar_assert_chr(name)
  targets::tar_assert_nzchar(name)
  targets::tar_assert_scalar(file)
  targets::tar_assert_chr(file)
  targets::tar_assert_scalar(n_folds)
  targets::tar_assert_dbl(n_folds)
  targets::tar_assert_ge(n_folds, 2)

  # ... build targets
}
```

### Common Assertions

| Function | Checks |
|----------|--------|
| `tar_assert_chr(x)` | Character type |
| `tar_assert_nzchar(x)` | Non-empty string |
| `tar_assert_scalar(x)` | Length 1 |
| `tar_assert_dbl(x)` | Numeric type |
| `tar_assert_lgl(x)` | Logical type |
| `tar_assert_ge(x, min)` | x >= min |
| `tar_assert_le(x, max)` | x <= max |
| `tar_assert_in(x, choices)` | x in choices |
| `tar_assert_path(x)` | File exists |

## Pre-configuring Settings

Apply domain knowledge to set sensible defaults:

```r
#' Target factory for Bayesian models
#'
#' Pre-configures settings appropriate for Stan/brms models.
fit_bayesian_model <- function(name, formula, data_target) {
  name <- targets::tar_deparse_language(substitute(name))
  data_target <- targets::tar_deparse_language(substitute(data_target))

  command <- substitute(
    brms::brm(formula, data = data, chains = 4, cores = 4),
    env = list(formula = formula, data = as.symbol(data_target))
  )

  targets::tar_target_raw(
    name = name,
    command = command,
    format = "qs",
    memory = "transient",
    garbage_collection = TRUE,
    deployment = "worker",
    resources = targets::tar_resources(
      crew = targets::tar_resources_crew(
        controller = "high_memory"
      )
    )
  )
}
```

## Forwarding tar_target Arguments

Allow users to override defaults:

```r
my_factory <- function(
  name,
  command,
  format = targets::tar_option_get("format"),
  packages = targets::tar_option_get("packages"),
  ...
) {
  name <- targets::tar_deparse_language(substitute(name))
  command <- substitute(command)

  targets::tar_target_raw(
    name = name,
    command = command,
    format = format,
    packages = packages,
    ...
  )
}
```

## Factories with Branching

### Static Branching in Factory

```r
#' Create cross-validated model targets
fit_cv_model <- function(name, data_target, n_folds = 5) {
  name <- targets::tar_deparse_language(substitute(name))
  data_target <- targets::tar_deparse_language(substitute(data_target))

  values <- tibble::tibble(
    fold = seq_len(n_folds),
    fold_name = sprintf("fold%d", seq_len(n_folds))
  )

  # Use tarchetypes for static branching within factory
  tarchetypes::tar_map(
    values = values,
    names = "fold_name",
    targets::tar_target_raw(
      name = name,
      command = substitute(
        fit_fold(data, fold_id = fold),
        env = list(
          data = as.symbol(data_target),
          fold = fold
        )
      )
    )
  )
}
```

### Dynamic Branching in Factory

```r
#' Create target with dynamic branching over upstream
process_branches <- function(name, upstream_target) {
  name <- targets::tar_deparse_language(substitute(name))
  upstream <- targets::tar_deparse_language(substitute(upstream_target))

  command <- substitute(
    process_one(upstream),
    env = list(upstream = as.symbol(upstream))
  )

  pattern <- substitute(
    map(upstream),
    env = list(upstream = as.symbol(upstream))
  )

  targets::tar_target_raw(
    name = name,
    command = command,
    pattern = pattern
  )
}
```

## Testing Factories

### Using tar_dir() for Isolation

```r
# In tests or examples
targets::tar_dir({
  targets::tar_script({
    list(
      my_factory(test_analysis, "data.csv")
    )
  })

  # Verify manifest
  manifest <- targets::tar_manifest()
  testthat::expect_true("test_analysis_data" %in% manifest$name)
  testthat::expect_true("test_analysis_model" %in% manifest$name)
})
```

### Using tar_test() Pattern

```r
targets::tar_test("my_factory creates expected targets", {
  targets::tar_script({
    list(
      my_factory(foo, "input.csv")
    )
  })

  manifest <- targets::tar_manifest()
  expect_equal(nrow(manifest), 3)
  expect_true(all(c("foo_file", "foo_data", "foo_model") %in% manifest$name))
})
```

## Documenting Factories

```r
#' Analyze survey data with standard preprocessing
#'
#' Creates targets for loading, cleaning, and analyzing survey data.
#'
#' @param name Symbol. Base name for generated targets. Creates:
#'   - `{name}_raw`: Raw data from file
#'   - `{name}_clean`: Cleaned data
#'   - `{name}_summary`: Analysis summary
#' @param file Character. Path to survey CSV file.
#' @param weights Character. Column name for survey weights (optional).
#'
#' @return List of target objects to include in `_targets.R`.
#'
#' @examples
#' # In _targets.R:
#' list(
#'   analyze_survey(customer_survey, "data/customers.csv"),
#'   analyze_survey(employee_survey, "data/employees.csv", weights = "sample_weight")
#' )
#'
#' @export
analyze_survey <- function(name, file, weights = NULL) {
  # ... implementation
}
```

## Complete Example: Multi-Step Analysis Factory

```r
#' Create complete analysis pipeline for a dataset
#'
#' @param name Base name (symbol)
#' @param file Data file path
#' @param model_fn Modeling function (symbol)
#' @param preprocess_fn Preprocessing function (symbol, default: identity)
#' @export
full_analysis <- function(
  name,
  file,
  model_fn,
  preprocess_fn = identity
) {
  # Parse inputs
  name <- targets::tar_deparse_language(substitute(name))
  model_fn_str <- targets::tar_deparse_language(substitute(model_fn))
  preprocess_fn_str <- targets::tar_deparse_language(substitute(preprocess_fn))

  # Validate
  targets::tar_assert_chr(name)
  targets::tar_assert_nzchar(name)
  targets::tar_assert_chr(file)
  targets::tar_assert_scalar(file)

  # Build target names
  name_file <- paste0(name, "_file")
  name_raw <- paste0(name, "_raw")
  name_clean <- paste0(name, "_clean")
  name_model <- paste0(name, "_model")
  name_diagnostics <- paste0(name, "_diagnostics")

  # Build symbols
  sym_raw <- as.symbol(name_raw)
  sym_clean <- as.symbol(name_clean)
  sym_model <- as.symbol(name_model)
  sym_model_fn <- as.symbol(model_fn_str)
  sym_preprocess <- as.symbol(preprocess_fn_str)

  # Build commands
  cmd_raw <- bquote(readr::read_csv(.(file)))
  cmd_clean <- bquote(.(sym_preprocess)(.(sym_raw)))
  cmd_model <- bquote(.(sym_model_fn)(.(sym_clean)))
  cmd_diagnostics <- bquote(compute_diagnostics(.(sym_model)))

  list(
    targets::tar_target_raw(
      name_file,
      command = bquote(.(file)),
      format = "file"
    ),
    targets::tar_target_raw(
      name_raw,
      command = cmd_raw,
      format = "qs"
    ),
    targets::tar_target_raw(
      name_clean,
      command = cmd_clean,
      format = "qs"
    ),
    targets::tar_target_raw(
      name_model,
      command = cmd_model,
      format = "qs"
    ),
    targets::tar_target_raw(
      name_diagnostics,
      command = cmd_diagnostics
    )
  )
}
```

## See Also

- **r-metaprogramming**: Advanced expression manipulation
- [targetopia-packages.md](targetopia-packages.md): Package development workflows
- [references/targets-utilities.md](references/targets-utilities.md): Utility functions for factories
- [templates/target-factory.R](templates/target-factory.R): Starter template
