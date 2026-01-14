# tarchetypes Function Reference

Quick reference for `tarchetypes` functions used in branching patterns.

## Static Branching

| Function | Purpose | Key Arguments |
|----------|---------|---------------|
| `tar_map()` | Create target variants from values data frame | `values`, `names`, `unlist` |
| `tar_combine()` | Aggregate results from multiple targets | `name`, `...targets`, `command` |
| `tar_eval()` | Evaluate expression with substitution | `expr`, `values` |
| `tar_sub()` | Substitute values into expression (no eval) | `expr`, `values` |

### tar_map()

```r
tarchetypes::tar_map(
  values,
  ...,
  names = tidyselect::everything(),
  descriptions = tidyselect::everything(),
  unlist = TRUE,
  delimiter = "_"
)
```

| Argument | Description |
|----------|-------------|
| `values` | Data frame where each row defines one variant |
| `...` | Target definitions using column names from `values` |
| `names` | Columns to use for target name suffixes |
| `unlist` | If `FALSE`, return nested list (required for `tar_combine()`) |
| `delimiter` | Separator between base name and suffix (default `"_"`) |

### tar_combine()

```r
tarchetypes::tar_combine(
  name,
  ...,
  command = NULL,
  use_names = TRUE,
  pattern = NULL,
  ...
)
```

| Argument | Description |
|----------|-------------|
| `name` | Name of combined target |
| `...` | Targets to combine (or list from `tar_map(..., unlist = FALSE)`) |
| `command` | Aggregation expression; use `!!!.x` to splice upstream results |
| `use_names` | Include target names in combined result |

## Dynamic Data Frame Grouping

| Function | Strategy | Key Arguments |
|----------|----------|---------------|
| `tar_group_by()` | Group by columns | `name`, `command`, `...columns` |
| `tar_group_count()` | Fixed number of groups | `name`, `command`, `count` |
| `tar_group_size()` | Fixed rows per group | `name`, `command`, `size` |
| `tar_group_select()` | Group with tidyselect | `name`, `command`, `...selection` |

### tar_group_by()

```r
tarchetypes::tar_group_by(
  name,
  command,
  ...,
  tidy_eval = targets::tar_option_get("tidy_eval"),
  packages = targets::tar_option_get("packages"),
  ...
)
```

Creates a target with `iteration = "group"`. Downstream targets use `pattern = map(grouped_target)` to branch over groups.

```r
list(
  tarchetypes::tar_group_by(grouped_data, load_data(), region, year),
  targets::tar_target(
    analysis,
    analyze(grouped_data),
    pattern = map(grouped_data)
  )
)
```

### tar_group_count()

```r
tarchetypes::tar_group_count(
  name,
  command,
  count,
  ...
)
```

Splits data into exactly `count` groups (rows distributed as evenly as possible).

### tar_group_size()

```r
tarchetypes::tar_group_size(
  name,
  command,
  size,
  ...
)
```

Splits data into groups of approximately `size` rows each.

## Batched Replication

| Function | Purpose | Key Arguments |
|----------|---------|---------------|
| `tar_rep()` | Batched replication | `name`, `command`, `batches`, `reps` |
| `tar_map_rep()` | Static variants + batching | `name`, `command`, `values`, `batches`, `reps` |
| `tar_rep_raw()` | Raw version of `tar_rep()` | Same as `tar_rep()` |
| `tar_rep_index()` | Get current rep index in batch | (no args) |

### tar_rep()

```r
tarchetypes::tar_rep(
  name,
  command,
  batches = 1,
  reps = 1,
  rep_workers = 1,
  tidy_eval = targets::tar_option_get("tidy_eval"),
  packages = targets::tar_option_get("packages"),
  iteration = targets::tar_option_get("iteration"),
  ...
)
```

| Argument | Description |
|----------|-------------|
| `batches` | Number of dynamic branches |
| `reps` | Replications per batch |
| `rep_workers` | Max parallel workers within a batch |

Output includes `tar_batch`, `tar_rep`, and `tar_seed` columns.

**Seed invariance:** Same results regardless of `batches`/`reps` split:

```r
# All produce identical results:
tarchetypes::tar_rep(x, rnorm(1), batches = 100, reps = 1)
tarchetypes::tar_rep(x, rnorm(1), batches = 10, reps = 10)
tarchetypes::tar_rep(x, rnorm(1), batches = 1, reps = 100)
```

### tar_map_rep()

```r
tarchetypes::tar_map_rep(
  name,
  command,
  values = NULL,
  names = NULL,
  descriptions = NULL,
  batches = 1,
  reps = 1,
  rep_workers = 1,
  ...
)
```

Combines static branching (via `values`) with batched replication.

```r
values <- tibble::tibble(
  method = rlang::syms(c("method_a", "method_b")),
  method_name = c("a", "b")
)

tarchetypes::tar_map_rep(
  sim,
  method(simulate_data()),
  values = values,
  names = "method_name",
  batches = 10,
  reps = 100
)
# Creates: sim_a, sim_b (each with 10 batches x 100 reps = 1000 total)
```

### tar_rep_index()

Returns the current replication index within a batch. Useful for conditional logic:

```r
tarchetypes::tar_rep(
  sim,
  {
    idx <- tarchetypes::tar_rep_index()
    if (idx == 1) {
      # First rep: full output
      list(full = TRUE, result = simulate())
    } else {
      # Subsequent: just result
      list(full = FALSE, result = simulate())
    }
  },
  batches = 10,
  reps = 100
)
```

## File Tracking

| Function | Purpose |
|----------|---------|
| `tar_files()` | Track multiple files with dynamic branching |
| `tar_files_input()` | Track input files only |
| `tar_files_raw()` | Raw version of `tar_files()` |

### tar_files()

```r
tarchetypes::tar_files(
  name,
  command,
  tidy_eval = targets::tar_option_get("tidy_eval"),
  packages = targets::tar_option_get("packages"),
  ...
)
```

Creates file-tracking target that branches dynamically:

```r
list(
  tarchetypes::tar_files(data_files, list.files("data/", full.names = TRUE)),
  targets::tar_target(
    loaded,
    readr::read_csv(data_files),
    pattern = map(data_files)
  )
)
```

## Pattern Testing

| Function | Purpose |
|----------|---------|
| `targets::tar_pattern()` | Test pattern logic without running |

```r
# Test how patterns compose
targets::tar_pattern(
  cross(method, map(dataset, seed)),
  method = 3,
  dataset = 5,
  seed = 5
)
#> Shows expected branch structure
```

## Hook Functions

| Function | Purpose |
|----------|---------|
| `tar_hook_before()` | Insert code before target command |
| `tar_hook_after()` | Insert code after target command |
| `tar_hook_inner()` | Wrap command expression |
| `tar_hook_outer()` | Wrap entire target |

Useful for logging, timing, or resource management across many targets.
