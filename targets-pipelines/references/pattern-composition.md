# Pattern Composition Reference

Patterns in dynamic branching define how targets are sliced and combined. Understanding pattern algebra helps design efficient branching strategies.

## Pattern Types

| Pattern | Behavior | Analogy |
|---------|----------|---------|
| `map(x)` | One branch per element | `purrr::map()` |
| `map(x, y)` | Parallel iteration (zip) | `purrr::map2()` |
| `cross(x, y)` | All combinations | `tidyr::crossing()` |
| `head(x, n)` | First n elements | `head()` |
| `tail(x, n)` | Last n elements | `tail()` |
| `slice(x, index)` | Specific indices | `dplyr::slice()` |
| `sample(x, n)` | Random sample | `sample()` |

## Pattern Algebra

### map() - Parallel Iteration

Elements from multiple targets are zipped together:

```r
# x = [1, 2, 3], y = [a, b, c]
pattern = map(x, y)
# Branches: (1,a), (2,b), (3,c)
```

**Requirement:** All targets in `map()` must have the same length.

### cross() - Cartesian Product

Every combination of elements:

```r
# x = [1, 2], y = [a, b]
pattern = cross(x, y)
# Branches: (1,a), (1,b), (2,a), (2,b)
```

### Composing Patterns

Patterns can be nested. The outer pattern determines the primary structure:

```r
# Cross methods with mapped (dataset, seed) pairs
pattern = cross(method, map(dataset, seed))

# With method = [A, B], dataset = [d1, d2], seed = [s1, s2]:
# Branches:
#   A with (d1, s1)
#   A with (d2, s2)
#   B with (d1, s1)
#   B with (d2, s2)
```

```r
# Map over methods, cross datasets and seeds within each
pattern = map(method, cross(dataset, seed))

# With method = [A, B], dataset = [d1, d2], seed = [s1, s2]:
# Branches:
#   A with (d1, s1)
#   A with (d1, s2)
#   A with (d2, s1)
#   A with (d2, s2)
#   B with (d1, s1)
#   ... (8 total)
```

## Testing Patterns

Always test complex patterns before running:

```r
targets::tar_pattern(
  cross(method, map(dataset, seed)),
  method = 3,
  dataset = 5,
  seed = 5
)
```

Output shows the expected branch structure and count.

## Equivalent tidyr Operations

| Pattern | tidyr Equivalent |
|---------|------------------|
| `map(x, y)` | `tibble(x, y)` (same length vectors) |
| `cross(x, y)` | `tidyr::crossing(x, y)` |
| `cross(a, map(b, c))` | `tidyr::crossing(a, tibble(b, c))` |

This mental model helps predict branch counts:

```r
# How many branches?
# cross(method, map(dataset, seed))
# = nrow(crossing(method, tibble(dataset, seed)))
# = length(method) * length(dataset)  # assuming dataset == seed length
```

## Subset Patterns

### head() and tail()

Useful for testing with a subset:

```r
# Run only first 3 branches
pattern = head(large_dataset, n = 3)

# Run last 5 branches
pattern = tail(large_dataset, n = 5)
```

### slice()

Select specific indices:

```r
# Run branches 1, 5, and 10
pattern = slice(dataset, index = c(1, 5, 10))
```

### sample()

Random subset (reproducible with pipeline seed):

```r
# Run 10 random branches
pattern = sample(dataset, n = 10)
```

## Aggregation Behavior

Dynamic branches auto-aggregate based on the `iteration` argument:

| `iteration` | Split function | Combine function |
|-------------|----------------|------------------|
| `"vector"` (default) | `vctrs::vec_slice()` | `vctrs::vec_c()` |
| `"list"` | `[[` | `list()` |
| `"group"` | Row groups | `vctrs::vec_rbind()` |

### Reading Aggregated Results

```r
# All branches combined
targets::tar_read(result)

# Specific branches only
targets::tar_read(result, branches = 1)
targets::tar_read(result, branches = c(2, 5, 7))
```

## Common Patterns

### File Processing

```r
list(
  tarchetypes::tar_files(data_files, list.files("data/", full.names = TRUE)),
  targets::tar_target(
    processed,
    process_file(data_files),
    pattern = map(data_files)
  )
)
```

### Parameter Grid

```r
list(
  targets::tar_target(alphas, c(0.1, 0.5, 1.0)),
  targets::tar_target(lambdas, c(0.01, 0.1, 1.0)),
  targets::tar_target(
    model,
    fit_model(data, alpha = alphas, lambda = lambdas),
    pattern = cross(alphas, lambdas)
  )
)
```

### Grouped Analysis

```r
list(
  tarchetypes::tar_group_by(grouped_data, load_data(), region),
  targets::tar_target(
    regional_analysis,
    analyze(grouped_data),
    pattern = map(grouped_data)
  )
)
```

### Parallel with Zip

```r
list(
  targets::tar_target(train_files, list.files("train/")),
  targets::tar_target(test_files, list.files("test/")),
  targets::tar_target(
    evaluation,
    evaluate(train_files, test_files),
    pattern = map(train_files, test_files)
  )
)
```

## Anti-Patterns

### External Objects in Patterns

```r
# WRONG: Patterns can't reference R objects
my_vec <- 1:10
targets::tar_target(x, f(my_vec), pattern = map(my_vec))

# CORRECT: Create upstream target
list(
  targets::tar_target(params, 1:10),
  targets::tar_target(x, f(params), pattern = map(params))
)
```

### Expressions in Patterns

```r
# WRONG: Can't use expressions
targets::tar_target(x, f(data), pattern = map(data$column))

# CORRECT: Extract column as upstream target
list(
  targets::tar_target(values, data$column),
  targets::tar_target(x, f(values), pattern = map(values))
)
```

### Mismatched Lengths in map()

```r
# ERROR: x has 3 elements, y has 5
targets::tar_target(result, f(x, y), pattern = map(x, y))

# If you want all combinations, use cross()
targets::tar_target(result, f(x, y), pattern = cross(x, y))
```
