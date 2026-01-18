# Dynamic Branching in targets

Dynamic branching creates targets at runtime based on upstream data. Use when the number or nature of branches isn't known until the pipeline runs.

## When to Use Dynamic Branching

- Branch count depends on data (files in directory, rows in table)
- Scaling to hundreds of thousands of branches
- Don't need human-readable target names
- Runtime efficiency more important than pre-run validation

## Core Concept: The pattern Argument

The `pattern` argument of `tar_target()` defines how to split upstream targets:

```r
list(
  tar_target(values, 1:5),
  tar_target(
    doubled,
    values * 2,
    pattern = map(values)  # One branch per element of 'values'
  )
)
```

**Critical:** `pattern` references **target names**, not R objects or expressions.

```r
# ❌ WRONG: Can't use external objects
my_vector <- 1:5
tar_target(x, process(my_vector), pattern = map(my_vector))

# ❌ WRONG: Can't use expressions
tar_target(x, process(data), pattern = map(data$column))

# ✅ CORRECT: Reference upstream target by name
list(
  tar_target(params, 1:5),
  tar_target(result, process(params), pattern = map(params))
)
```

## Pattern Types

### map() - Parallel Iteration

One branch per tuple of elements (like `purrr::map2` or `zip`):

```r
list(
  tar_target(x, 1:3),
  tar_target(y, c("a", "b", "c")),
  tar_target(
    result,
    paste(x, y),
    pattern = map(x, y)  # (1,"a"), (2,"b"), (3,"c")
  )
)
```

### cross() - Cartesian Product

One branch per combination:

```r
list(
  tar_target(x, 1:2),
  tar_target(y, c("a", "b")),
  tar_target(
    result,
    paste(x, y),
    pattern = cross(x, y)  # All 4 combinations
  )
)
```

### Subset Patterns

```r
# Specific indices
pattern = slice(x, index = c(1, 3, 5))

# First/last N
pattern = head(x, n = 10)
pattern = tail(x, n = 5)

# Random sample
pattern = sample(x, n = 100)
```

### Composing Patterns

Patterns are composable:

```r
# Cross outer, map inner
pattern = cross(method, map(dataset, seed))

# Test with tar_pattern() first
tar_pattern(
  cross(method, map(dataset, seed)),
  method = 3,
  dataset = 5,
  seed = 5
)
```

## Iteration Modes

The `iteration` argument controls how targets split and aggregate:

### iteration = "vector" (default)

Uses `vctrs::vec_slice()` to split, `vctrs::vec_c()` to combine.

```r
tar_target(
  result,
  process(data),
  pattern = map(data),
  iteration = "vector"  # Default
)
```

- Vectors → vectors
- Data frames → data frames (row binding)
- Type-consistent

### iteration = "list"

Uses `[[` to split, `list()` to combine.

```r
tar_target(
  plots,
  make_plot(data),
  pattern = map(data),
  iteration = "list"  # Required for ggplot objects
)
```

Use when:
- Return values can't be vectorized (ggplot2, model objects)
- Need list structure preserved

### iteration = "group"

Branch over row groups of a data frame:

```r
list(
  tar_target(
    grouped_data,
    data |>
      group_by(category) |>
      tar_group(),
    iteration = "group"  # Required
  ),
  tar_target(
    result,
    analyze_group(grouped_data),
    pattern = map(grouped_data)
  )
)
```

**Important:** Target with `iteration = "group"` must NOT have a `pattern` argument itself.

## Row Grouping Functions

`tarchetypes` provides helper functions for grouping:

### tar_group_by()

Group by specific columns:

```r
tar_group_by(
  grouped_data,
  load_data(),
  region, year  # Group by these columns
)
```

### tar_group_count()

Fixed number of groups (variable row counts):

```r
tar_group_count(
  batched_data,
  load_data(),
  count = 10  # Split into 10 groups
)
```

### tar_group_size()

Fixed rows per group (variable number of groups):

```r
tar_group_size(
  batched_data,
  load_data(),
  size = 1000  # ~1000 rows per group
)
```

## Batching for Performance

With many branches (>1000), overhead accumulates. Batch work:

### tar_rep() - Batched Replication

For simulation studies:

```r
tar_rep(
  simulation,
  {
    data <- simulate_data()
    fit_model(data)
  },
  batches = 10,   # 10 dynamic branches
  reps = 100      # 100 reps per batch
)
# Total: 1000 replications in 10 targets
```

Output includes `tar_batch`, `tar_rep`, and `tar_seed` columns.

**Seed invariance:** Results are the same regardless of batch structure:
```r
# Same results:
tar_rep(x, rnorm(1), batches = 100, reps = 1)
tar_rep(x, rnorm(1), batches = 10, reps = 10)
tar_rep(x, rnorm(1), batches = 1, reps = 100)
```

### tar_map_rep() - Static Variants + Batching

Combines static branching over parameters with batched replication:

```r
tar_map_rep(
  simulation,
  simulate_and_fit(method, n_obs),
  values = tibble(
    method = syms(c("method_a", "method_b")),
    n_obs = c(100, 500)
  ),
  batches = 10,
  reps = 50
)
```

## Branching Over Files

Files require special handling because `format = "file"` treats all files as one unit:

```r
# ❌ WRONG: Can't branch over file target directly
list(
  tar_target(files, list.files("data/"), format = "file"),
  tar_target(data, read_csv(files), pattern = map(files))
)

# ✅ CORRECT: Create one file target per path
list(
  tar_target(paths, list.files("data/", full.names = TRUE)),
  tar_target(files, paths, format = "file", pattern = map(paths)),
  tar_target(data, read_csv(files), pattern = map(files))
)

# ✅ SIMPLER: Use tar_files()
list(
  tar_files(files, list.files("data/", full.names = TRUE)),
  tar_target(data, read_csv(files), pattern = map(files))
)
```

## Implementation Steps

1. **Create upstream target**: Define data that determines branches
2. **Add pattern argument**: Reference upstream target(s) by name
3. **Choose pattern type**: `map()` for parallel, `cross()` for combinations
4. **Set iteration mode**: `"list"` for non-vectorizable returns
5. **Consider batching**: Use `tar_rep()` for >1000 branches
6. **Test pattern**: Use `tar_pattern()` before running
7. **Validate**: Run small subset first with `head()` or `slice()`

## Complete Example

Processing multiple data files with parameter grid:

```r
# _targets.R
library(targets)
library(tarchetypes)

list(
  # Discover files dynamically
  tar_target(file_paths, list.files("data/", pattern = "\\.csv$", full.names = TRUE)),

  # Track each file
  tar_files(data_files, file_paths),

  # Load each file
  tar_target(
    raw_data,
    read_csv(data_files),
    pattern = map(data_files)
  ),

  # Parameters for analysis
  tar_target(thresholds, c(0.01, 0.05, 0.1)),

  # Cross files with thresholds
  tar_target(
    analysis,
    analyze(raw_data, threshold = thresholds),
    pattern = cross(raw_data, thresholds)
  ),

  # Aggregate results
  tar_target(
    summary,
    analysis |>
      group_by(threshold) |>
      summarize(mean_result = mean(result))
  )
)
```

## Provenance and Debugging

Include metadata in branch outputs for traceability:

```r
tar_target(
  result,
  {
    out <- process(data, param)
    out$param_value <- param  # Track which param created this
    out$data_source <- attr(data, "source")
    out
  },
  pattern = cross(data, param)
)
```

When a branch fails, you can identify which inputs caused it.

## Reading Branch Results

```r
# All branches combined (uses iteration mode)
tar_read(result)

# Specific branch by index
tar_read(result, branches = 1)
tar_read(result, branches = c(2, 5, 7))

# Load into environment
tar_load(result)
tar_load(result, branches = 1:3)
```

## Validation

```r
# Test pattern logic with mock sizes
tar_pattern(
  cross(x, map(y, z)),
  x = 3,
  y = 5,
  z = 5
)

# Run subset first
list(
  tar_target(params, 1:1000),
  tar_target(
    result,
    slow_computation(params),
    pattern = head(params, n = 10)  # Test with 10 first
  )
)
```
