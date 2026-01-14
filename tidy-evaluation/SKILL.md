---
name: tidy-evaluation
description: >
  Use when programming with tidyverse data-masked functions (dplyr, ggplot2,
  tidyr) and need to pass column references through functions. Covers:
  forwarding patterns with {{ and ..., names patterns with .data/.env pronouns,
  bridge patterns with across()/all_of(), double evaluation and ambiguity
  pitfalls. Does NOT cover: expression mechanics (r-metaprogramming), error
  handling (rlang-conditions), function design (designing-tidy-r-functions).
dependencies: R>=4.3, rlang>=1.1.3
---

# Tidy Evaluation Programming Patterns

Data masking lets you refer to data frame columns as if they were regular objects. Programming with data-masked functions requires special patterns to pass column references through your functions.

## Quick Reference

| Goal | Pattern |
|------|---------|
| Forward single argument | `{{ var }}` |
| Forward `...` to data-mask | `...` directly |
| Forward `...` to tidy-select (single arg) | `c(...)` |
| Use column name from string | `.data[[var]]` |
| Use column names from vector | `across(all_of(vars))` |
| Disambiguate env-variable | `.env$x` |
| Disambiguate data-variable | `.data$x` |
| Bridge selection to data-mask | `across({{ var }})` |
| Bridge names to data-mask | `across(all_of(vars))` |
| Bridge data-mask to selection | `transmute()` then `all_of()` |
| Prevent double evaluation | Assign to column first |

## What is Data Masking?

Data masking inserts a data frame at the bottom of the environment chain, giving columns precedence over user-defined variables:

```r
# Without masking: must use $ notation
mean(mtcars$cyl + mtcars$am)

# With masking: columns are directly accessible
with(mtcars, mean(cyl + am))
dplyr::summarise(mtcars, mean(cyl + am))
```

### Why Injection is Needed

Data-masking functions defuse their arguments. When you wrap them, you must inject the user's expression:

```r
# Without injection: summarise sees literal "var1 + var2"
my_mean <- function(data, var1, var2) {
  dplyr::summarise(data, mean(var1 + var2))  # Error!
}

# With injection: summarise sees "cyl + am"
my_mean <- function(data, var1, var2) {
  dplyr::summarise(data, mean({{ var1 }} + {{ var2 }}))
}
```

## Argument Behaviors

| Behavior | Example Functions | Key Features |
|----------|-------------------|--------------|
| Data-masked | `mutate()`, `summarise()`, `filter()` | Column refs, `.data`/`.env`, `{{`, `!!` |
| Tidy-select | `select()`, `pivot_longer(cols=)` | Helpers (`starts_with`), `c()`, `:`, `{{` |
| Dynamic dots | `list2()`, `tibble()` | `!!!` splice, `{name}` interpolation |

### Documenting Argument Behaviors

```r
#' @param var <[`data-masked`][dplyr::dplyr_data_masking]> Column to summarize.
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to pivot.
#' @param ... <[`dynamic-dots`][rlang::dyn-dots]> Name-value pairs.
```

## Forwarding Patterns

### Single Argument with `{{}}`

The embrace operator forwards an argument, inheriting behavior from the wrapped function:

```r
# Forwarding to data-masked context
my_summarise <- function(data, var) {
  data |> dplyr::summarise({{ var }})
}
mtcars |> my_summarise(mean(cyl))

# Forwarding to tidy-select context
my_pivot <- function(data, cols) {
  data |> tidyr::pivot_longer(cols = {{ cols }})
}
mtcars |> my_pivot(starts_with("c"))
```

### Multiple Arguments with `...`

Pass `...` directly to data-masked functions:

```r
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(...)
}
mtcars |> my_group_by(cyl, am)
```

For tidy-select functions taking a single argument, wrap in `c()`:

```r
my_pivot <- function(.data, ...) {
  .data |> tidyr::pivot_longer(c(...))
}
mtcars |> my_pivot(cyl, am, vs)
```

## Names Patterns

Use strings or character vectors instead of expressions. Your function becomes "regular" with no data-masking complications.

### `.data[[var]]` for Single Column

```r
my_mean <- function(data, var) {
  data |> dplyr::summarise(mean = mean(.data[[var]]))
}
my_mean(mtcars, "cyl")

# No masking surprises
am <- "cyl"
my_mean(mtcars, am)  # Uses "cyl", not masked
```

### `all_of()` for Character Vectors

```r
vars <- c("cyl", "am")
mtcars |> tidyr::pivot_longer(all_of(vars))
mtcars |> dplyr::select(all_of(vars))
```

### Loop Pattern

```r
vars <- c("cyl", "am", "vs")
for (var in vars) {
  result <- mtcars |>
    dplyr::summarise(mean = mean(.data[[var]]))
  print(result)
}

# Or with purrr
purrr::map(vars, ~ dplyr::summarise(mtcars, mean = mean(.data[[.x]])))
```

## Bridge Patterns

Convert between argument behaviors when the wrapped function doesn't match your desired interface.

### Selection to Data-Mask: `across()`

Give your function tidy-select behavior when wrapping a data-masked function:

```r
my_group_by <- function(data, var) {
  data |> dplyr::group_by(across({{ var }}))
}
# Now supports selection helpers:
mtcars |> my_group_by(starts_with("c"))
```

For `...`, wrap in `c()`:

```r
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(across(c(...)))
}
```

### Names to Data-Mask: `across(all_of())`

Accept character vectors for data-masked operations:

```r
my_group_by <- function(data, vars) {
  data |> dplyr::group_by(across(all_of(vars)))
}
my_group_by(mtcars, c("cyl", "am"))
```

### Data-Mask to Selection: `transmute()` Bridge

Three-step pattern for data-masked input to tidy-select functions:

```r
my_pivot_longer <- function(data, ...) {
  # 1. Capture inputs in data-masked context, get names
  inputs <- dplyr::transmute(data, ...)
  names <- names(inputs)

  # 2. Update data with the expressions
  data <- dplyr::mutate(data, !!!inputs)

  # 3. Pass names to tidy-select
 tidyr::pivot_longer(data, cols = all_of(names))
}

mtcars |> my_pivot_longer(cyl, am_scaled = am * 100)
```

## Transformation Patterns

### Named Arguments: Code Around `{{}}`

Add code around embraced arguments:

```r
my_mean <- function(data, var) {
  data |> dplyr::summarise(mean = mean({{ var }}, na.rm = TRUE))
}
```

### `...` Arguments: Use `across()`

Map an expression across multiple columns:

```r
my_mean <- function(data, ...) {
  data |> dplyr::summarise(
    across(c(...), ~ mean(.x, na.rm = TRUE))
  )
}
mtcars |> my_mean(cyl, disp, hp)
```

### Filter with `if_all()` / `if_any()`

Combine logical conditions across columns:
```r
filter_non_min <- function(.data, ...) {
  .data |> dplyr::filter(
    if_all(c(...), ~ .x != min(.x, na.rm = TRUE))
  )
}

filter_any_max <- function(.data, ...) {
  .data |> dplyr::filter(
    if_any(c(...), ~ .x == max(.x, na.rm = TRUE))
  )
}
```

## Disambiguation: .data and .env Pronouns

Data masking can cause collisions when variable names exist in both the data and environment.

### Column Collisions

```r
x <- 100
df <- data.frame(x = 1:3, y = 4:6)

# Ambiguous: which x?
df |> dplyr::mutate(z = y / x)
#> Uses column x (data takes precedence)

# Explicit: use environment x
df |> dplyr::mutate(z = y / .env$x)
```

### In Functions (Critical)

Always use `.env` for function parameters that might collide:

```r
my_rescale <- function(data, var, factor = 10) {
  # Safe even if data has a 'factor' column
  data |> dplyr::mutate(
    "{{ var }}" := {{ var }} / .env$factor
  )
}
```

### Full Disambiguation

```r
df |> dplyr::mutate(
  result = .data$y / .env$x
)
```

## Pitfalls

### Double Evaluation

Expressions injected multiple times execute multiple times:

```r
# BAD: times100() runs twice
summarise_stats <- function(data, var) {
  data |> dplyr::summarise(
    mean = mean({{ var }}),
    sd = sd({{ var }})
  )
}
# If var = times100(cyl), function executes twice

# GOOD: Evaluate once, reference result
summarise_stats <- function(data, var) {
  data |>
    dplyr::transmute(var = {{ var }}) |>
    dplyr::summarise(mean = mean(var), sd = sd(var))
}
```

Exception: Glue strings (`"{{ var }}"`) don't suffer from double evaluation.

### `{{` Out of Context

Outside data-masking, `{{` becomes literal double-braces and silently returns the value:

```r
# In non-tidy-eval function:
f <- function(x) {{ x }}
f(1 + 1)
#> [1] 2  # No error, but not defuse-and-inject
```

### `!!` and `!!!` Out of Context

Outside injection context, these become logical negation:

```r
x <- TRUE
!!x    # Double negation: TRUE
!!!x   # Triple negation: FALSE
```

No error, just wrong semantics.

### `{{` on Non-Arguments

`{{` should only wrap function arguments:

```r
# Correct
my_fn <- function(arg) {
  summarise(data, {{ arg }})
}

# Problematic: x is not a defused argument
x <- expr(cyl)
summarise(data, {{ x }})  # Captures x's VALUE, not expression
```

## Tidy Selection vs Data Masking

Tidy selection is *not* data masking. It interprets expressions rather than masking environments, so there's no ambiguity:

```r
data <- data.frame(x = 1, data = 2)

# Tidy selection: no collision
data |> dplyr::select(data:ncol(data))
#> Works correctly

# Data masking: potential collision
data |> dplyr::mutate(y = data + 1)
#> Uses column 'data', not the data frame
```

## See Also

- **r-metaprogramming**: Defusing, quosures, expression building mechanics
- **designing-tidy-r-functions**: Function API design principles
- **rlang-conditions**: Error handling with rlang

## Reference Files

- [topic-data-mask.Rmd](topic-data-mask.Rmd) - Data masking concepts and history
- [topic-data-mask-programming.Rmd](topic-data-mask-programming.Rmd) - Complete programming guide
- [topic-data-mask-ambiguity.Rmd](topic-data-mask-ambiguity.Rmd) - Collision details
- [topic-double-evaluation.Rmd](topic-double-evaluation.Rmd) - Double evaluation problem
- [topic-inject-out-of-context.Rmd](topic-inject-out-of-context.Rmd) - Operator misuse
- [topic-embrace-non-args.Rmd](topic-embrace-non-args.Rmd) - Embrace on non-arguments
