# Static Branching in targets

Static branching defines all targets before `tar_make()` runs. Use when you know your iterations at define-time: methods to compare, models to fit, datasets to analyze.

## When to Use Static Branching

- Parameter values known when writing `_targets.R`
- Need friendly, readable target names
- Want to validate with `tar_manifest()` before running
- Fewer than ~1000 combinations

## Core Functions

### tar_map() - Create Target Variants

Creates copies of target definitions, substituting values from a data frame:

```r
library(tarchetypes)
library(tibble)
library(rlang)

values <- tibble(
  method = syms(c("analyze_bayesian", "analyze_frequentist")),
  prior = c("weak", "strong")
)

tar_map(
  values = values,
  names = "prior",  # Column(s) for target name suffixes
  tar_target(result, method(data, prior_type = prior)),
  tar_target(summary, summarize_result(result))
)
```

**Result:** Creates `result_weak`, `result_strong`, `summary_weak`, `summary_strong`.

#### Key Arguments

| Argument | Purpose | Example |
|----------|---------|---------|
| `values` | Data frame of parameters | `tibble(x = 1:3)` |
| `names` | Columns for target name suffixes | `names = c("method", "dataset")` |
| `unlist` | Return nested list (for `tar_combine()`) | `unlist = FALSE` |
| `delimiter` | Separator in target names | `delimiter = "_"` (default) |

#### Working with Function Names

**Critical:** Function names must be symbols, not strings:

```r
# ❌ WRONG: Strings can't be called
values <- tibble(method = c("method_a", "method_b"))

# ✅ CORRECT: Use rlang::syms()
values <- tibble(method = syms(c("method_a", "method_b")))

# ✅ ALSO CORRECT: Use rlang::sym() for single values
values <- tibble(method = list(sym("method_a"), sym("method_b")))
```

#### All Combinations with expand_grid

```r
library(tidyr)

values <- expand_grid(
  method = syms(c("method_a", "method_b")),
  dataset = c("train", "test"),
  seed = 1:3
)
# Creates 2 × 2 × 3 = 12 rows
```

### tar_combine() - Aggregate Results

Combines results from multiple targets into one:

```r
# Simple case: combine two explicit targets
target1 <- tar_target(head_data, head(mtcars))
target2 <- tar_target(tail_data, tail(mtcars))

tar_combine(
  combined,
  target1, target2,
  command = dplyr::bind_rows(!!!.x)
)
```

#### With tar_map()

```r
# Must use unlist = FALSE for selective combining
mapped <- tar_map(
  unlist = FALSE,
  values = tibble(method = syms(c("method_a", "method_b"))),
  tar_target(analysis, method(data)),
  tar_target(summary, summarize(analysis))
)

# Combine only summaries, not analyses
tar_combine(
  all_summaries,
  mapped[["summary"]],
  command = dplyr::bind_rows(!!!.x, .id = "method")
)
```

#### The `!!!.x` Syntax

`!!!.x` is rlang's unquote-splice operator. It expands `.x` (the list of upstream target results) into separate arguments:

```r
# This command:
command = dplyr::bind_rows(!!!.x)

# Becomes (with 3 upstream targets):
dplyr::bind_rows(result_a, result_b, result_c)
```

Custom aggregation:

```r
# Mean across all results
command = mean(c(!!!.x))

# Custom function
command = my_combine_function(!!!.x, weights = c(0.5, 0.3, 0.2))
```

### tar_eval() and tar_sub() - Custom Metaprogramming

When `tar_map()` isn't flexible enough:

```r
library(rlang)

# tar_sub: create expressions with substitution
tar_sub(
  tar_target(symbol, get_data(string)),
  values = list(
    string = c("data_a", "data_b"),
    symbol = syms(c("data_a", "data_b"))
  )
)

# tar_eval: create AND evaluate (returns target objects)
tar_eval(
  tar_target(symbol, get_data(string)),
  values = list(
    string = c("data_a", "data_b"),
    symbol = syms(c("data_a", "data_b"))
  )
)
```

## Combining Static + Dynamic

Static branching for outer layer (methods), dynamic for inner (seeds/reps):

```r
random_seeds <- tar_target(seeds, 1:100)

mapped <- tar_map(
  values = tibble(method = syms(c("method_a", "method_b"))),
  tar_target(
    analysis,
    method(data, seed = seeds),
    pattern = map(seeds)  # Dynamic branching over seeds
  ),
  tar_target(
    summary,
    summarize(analysis),
    pattern = map(analysis)
  )
)

list(random_seeds, mapped)
```

## Implementation Steps

1. **Identify what varies**: List parameters that differ across targets
2. **Build values data frame**: Use `tibble()`, convert functions with `syms()`
3. **Write base targets**: Create `tar_target()` calls using parameter names
4. **Wrap in tar_map()**: Pass values and targets
5. **Add tar_combine() if needed**: Use `unlist = FALSE` for selective combining
6. **Validate**: Run `tar_manifest()` to check generated targets

## Complete Example

```r
# _targets.R
library(targets)
library(tarchetypes)
library(tibble)
library(tidyr)
library(rlang)

# Define parameter grid
methods <- c("glm", "rf", "xgb")
datasets <- c("train", "validation", "test")

values <- expand_grid(
  method = syms(paste0("fit_", methods)),
  method_name = methods,
  dataset = datasets
)

list(
  # Data loading (static over datasets)
  tar_map(
    values = tibble(dataset = datasets),
    tar_target(data, load_data(dataset))
  ),

  # Model fitting (static over methods × datasets)
  tar_map(
    unlist = FALSE,
    values = values,
    names = c("method_name", "dataset"),
    tar_target(
      model,
      method(get(paste0("data_", dataset)))
    ),
    tar_target(
      predictions,
      predict(model, newdata = get(paste0("data_", dataset)))
    ),
    tar_target(
      metrics,
      compute_metrics(predictions, get(paste0("data_", dataset)))
    )
  ),

  # Combine all metrics
  tar_combine(
    all_metrics,
    mapped[["metrics"]],
    command = bind_rows(!!!.x, .id = "model_dataset") |>
      separate(model_dataset, c("method", "dataset"), sep = "_")
  )
)
```

## Limitations

- Complex nested objects may not substitute correctly (use `quote()`)
- Scales poorly beyond ~1000 targets (use dynamic branching)
- `tar_visnetwork()` becomes slow with many targets

## Validation

```r
# Check target definitions
tar_manifest()

# Check specific fields
tar_manifest(fields = c("name", "command"))

# Visualize (may be slow with many targets)
tar_visnetwork(targets_only = TRUE)
```
