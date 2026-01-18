# Dynamic Within Static Branching

Hybrid branching combines static branching (for known variants like methods or scenarios) with dynamic branching (for runtime-determined iterations like replications or data-driven splits).

## When to Use Hybrid Patterns

- **Simulation studies**: Compare methods across many replications
- **Bootstrap analysis**: Multiple methods, each with bootstrap samples
- **Cross-validation**: Known fold structure with data-dependent splits
- **Parameter sweeps**: Known parameter grid with batched execution

The key insight: static branching gives you friendly target names for high-level variants, while dynamic branching handles the scale of replications efficiently.

## tar_map_rep(): The Primary Hybrid Function

`tarchetypes::tar_map_rep()` combines `tar_map()` with `tar_rep()`:

```r
values <- tibble::tibble(
  method = rlang::syms(c("method_glm", "method_rf", "method_xgb")),
  method_name = c("glm", "rf", "xgb")
)

tarchetypes::tar_map_rep(
  name = simulation,
  command = {
    data <- simulate_data(n = 500)
    method(data)
  },
  values = values,
  names = "method_name",
  batches = 10,
  reps = 100
)
```

**Result:** Creates `simulation_glm`, `simulation_rf`, `simulation_xgb`, each with 10 dynamic branches containing 100 replications (1000 total reps per method).

### Key Arguments

| Argument | Purpose |
|----------|---------|
| `name` | Base name for generated targets |
| `command` | Expression to execute (can reference columns from `values`) |
| `values` | Data frame of static variants (same as `tar_map()`) |
| `names` | Column(s) for target name suffixes |
| `batches` | Number of dynamic branches |
| `reps` | Replications per batch |
| `rep_workers` | Max parallel workers per target (default 1) |

### Output Structure

Each batch includes metadata columns:

```r
# After tar_make(), reading a result:
targets::tar_read(simulation_glm)
#> # A tibble: 1,000 x 5
#>    tar_batch tar_rep tar_seed   estimate std_error
#>        <int>   <int>    <int>      <dbl>     <dbl>
#>  1         1       1 12345678      0.502    0.0312
#>  2         1       2 23456789      0.498    0.0298
#>  ...
```

- `tar_batch`: Which dynamic branch (1 to `batches`)
- `tar_rep`: Which replication within batch (1 to `reps`)
- `tar_seed`: Seed used for reproducibility

### Seed Invariance

Results are deterministic regardless of batch structure:

```r
# These produce identical results (same seeds):
tarchetypes::tar_rep(x, rnorm(1), batches = 100, reps = 1)
tarchetypes::tar_rep(x, rnorm(1), batches = 10, reps = 10)
tarchetypes::tar_rep(x, rnorm(1), batches = 1, reps = 100)
```

This allows tuning batch size for performance without affecting reproducibility.

## Manual Hybrid Construction

For cases `tar_map_rep()` doesn't cover, construct manually with `tar_map()` + `pattern`:

```r
# Static branching over methods
methods <- tibble::tibble(
  method = rlang::syms(c("method_a", "method_b")),
  method_name = c("a", "b")
)

list(
  # Upstream target that determines dynamic branch count
  targets::tar_target(seeds, 1:100),

  # Static map with dynamic pattern inside
  tarchetypes::tar_map(
    values = methods,
    names = "method_name",
    targets::tar_target(
      result,
      {
        set.seed(seeds)
        method(simulate_data())
      },
      pattern = map(seeds)
    )
  )
)
```

**Result:** Creates `result_a` and `result_b`, each with 100 dynamic branches.

### When to Use Manual Construction

- Need custom aggregation at the dynamic level
- Dynamic branch count varies by static variant
- Complex dependencies between static variants

## Aggregating Hybrid Results

### Within Static Variants

Dynamic branches auto-aggregate based on `iteration` mode:

```r
# All 1000 reps combined (iteration = "vector" default)
targets::tar_read(simulation_glm)

# Specific batches
targets::tar_read(simulation_glm, branches = 1:3)
```

### Across Static Variants

Combine static variants with explicit aggregation:

```r
list(
  tarchetypes::tar_map_rep(
    name = sim,
    command = method(simulate_data()),
    values = values,
    names = "method_name",
    batches = 10,
    reps = 100
  ),

  targets::tar_target(
    comparison,
    {
      results <- list(
        glm = targets::tar_read(sim_glm),
        rf = targets::tar_read(sim_rf),
        xgb = targets::tar_read(sim_xgb)
      )
      dplyr::bind_rows(results, .id = "method") |>
        dplyr::group_by(method) |>
        dplyr::summarize(
          mean_est = mean(estimate),
          bias = mean(estimate - true_value),
          rmse = sqrt(mean((estimate - true_value)^2)),
          .groups = "drop"
        )
    }
  )
)
```

### Programmatic Aggregation

When method names are dynamic:

```r
targets::tar_target(
  comparison,
  {
    method_names <- c("glm", "rf", "xgb")
    purrr::map_dfr(method_names, function(m) {
      targets::tar_read_raw(paste0("sim_", m)) |>
        dplyr::mutate(method = m)
    }) |>
      dplyr::group_by(method) |>
      dplyr::summarize(
        mean_est = mean(estimate),
        coverage = mean(ci_lower <= true_value & true_value <= ci_upper),
        .groups = "drop"
      )
  }
)
```

## Complete Example: Method Comparison Study

Compare three estimation methods across 1000 bootstrap replications:

```r
# _targets.R
values <- tibble::tibble(
  estimator = rlang::syms(c("est_mle", "est_bayes", "est_robust")),
  estimator_name = c("mle", "bayes", "robust")
)

list(
  # Load real data once
  targets::tar_target(
    observed_data,
    load_study_data("data/observations.csv")
  ),

  # Bootstrap each estimator
  tarchetypes::tar_map_rep(
    name = bootstrap,
    command = {
      boot_sample <- observed_data[sample(nrow(observed_data), replace = TRUE), ]
      estimator(boot_sample)
    },
    values = values,
    names = "estimator_name",
    batches = 20,
    reps = 50
  ),

  # Compare estimators
  targets::tar_target(
    comparison,
    {
      results <- dplyr::bind_rows(
        mle = targets::tar_read(bootstrap_mle),
        bayes = targets::tar_read(bootstrap_bayes),
        robust = targets::tar_read(bootstrap_robust),
        .id = "estimator"
      )

      results |>
        dplyr::group_by(estimator) |>
        dplyr::summarize(
          estimate = mean(value),
          se = sd(value),
          ci_lower = quantile(value, 0.025),
          ci_upper = quantile(value, 0.975),
          .groups = "drop"
        )
    }
  ),

  # Visualization
  targets::tar_target(
    plot,
    {
      ggplot2::ggplot(
        dplyr::bind_rows(
          mle = targets::tar_read(bootstrap_mle),
          bayes = targets::tar_read(bootstrap_bayes),
          robust = targets::tar_read(bootstrap_robust),
          .id = "estimator"
        ),
        ggplot2::aes(x = value, fill = estimator)
      ) +
        ggplot2::geom_density(alpha = 0.5) +
        ggplot2::labs(title = "Bootstrap Distributions by Estimator")
    },
    packages = "ggplot2"
  )
)
```

## Performance Considerations

### Batch Size Tuning

| Scenario | Recommendation |
|----------|----------------|
| Fast iterations (<1s each) | Larger batches (50-100 reps) |
| Slow iterations (>10s each) | Smaller batches (5-10 reps) |
| Memory-intensive | Smaller batches to limit memory |
| Distributed computing | Match batches to worker count |

### Memory Management

For memory-intensive simulations:

```r
tarchetypes::tar_map_rep(
  name = sim,
  command = run_simulation(),
  values = values,
  batches = 100,
  reps = 10,
  garbage_collection = TRUE,
  memory = "transient"
)
```

## Debugging Hybrid Pipelines

### Validate Structure First

```r
# Check static structure
targets::tar_manifest() |>
  dplyr::filter(stringr::str_detect(name, "^sim_"))

# Test pattern composition
targets::tar_pattern(
  map(seeds),
  seeds = 100
)
```

### Inspect Specific Branches

```r
# Read specific batch
targets::tar_read(sim_glm, branches = 1)

# Check batch metadata
targets::tar_read(sim_glm) |>
  dplyr::count(tar_batch)
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Missing `tar_batch` column | Not using `tar_map_rep()` | Use `tar_map_rep()` or add manually |
| Non-deterministic results | Missing seed management | Use `tar_rep()` family for automatic seeding |
| Memory exhaustion | Batches too large | Reduce `reps`, increase `batches` |
| Slow aggregation | Reading all branches | Use `branches` argument for subset |

## See Also

- [topic-static-branching.md](topic-static-branching.md) - Static branching details
- [topic-dynamic-branching.md](topic-dynamic-branching.md) - Dynamic branching details
- [references/tarchetypes-functions.md](references/tarchetypes-functions.md) - Function reference
