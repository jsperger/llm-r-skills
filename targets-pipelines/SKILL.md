---
name: targets-pipelines
description: >
  Use when writing complex targets pipelines with branching, batching, or custom
  target factories. Symptoms: multiple similar targets, parameter sweeps, method
  comparisons, simulation studies. Covers: static branching (tar_map/tar_combine),
  dynamic branching (pattern argument), hybrid patterns, custom target factories,
  pipeline debugging. Does NOT cover: basic targets usage, HPC deployment,
  package development workflows (see targetopia-packages.md).
dependencies: R>=4.3, targets>=1.9.0, tarchetypes>=0.12.0
---

# Complex targets Pipelines

Branching creates multiple targets from a single definition. Choose your approach based on when iterations are known and what naming you need.

## Quick Reference

| Task | Approach | Key Function/Pattern |
|------|----------|---------------------|
| Variants from known parameters | Static | `tarchetypes::tar_map()` |
| Aggregate static variants | Static | `tarchetypes::tar_combine()` |
| Runtime-determined iterations | Dynamic | `pattern = map(x)` |
| All combinations (cartesian) | Dynamic | `pattern = cross(x, y)` |
| Batched simulation reps | Dynamic | `tarchetypes::tar_rep()` |
| Static variants + batched reps | Hybrid | `tarchetypes::tar_map_rep()` |
| Branch over row groups | Dynamic | `tarchetypes::tar_group_by()` |
| Reusable multi-target pattern | Factory | Custom function + `tar_target_raw()` |

## Decision Tree

```
Need multiple similar targets?
│
├─ NO ──► Single target, or consider a target factory
│         for reusable patterns
│
└─ YES ─► Iterations known before tar_make()?
          │
          ├─ NO ──► DYNAMIC BRANCHING
          │         pattern = map() / cross()
          │         → topic-dynamic-branching.md
          │
          └─ YES ─► Need friendly target names in DAG?
                    │
                    ├─ YES ──► STATIC BRANCHING
                    │          tarchetypes::tar_map()
                    │          → topic-static-branching.md
                    │
                    └─ NO ───► Either works; prefer dynamic
                               for simplicity at scale

Additional decisions:

Static variants + many replications?
  └─► HYBRID: tarchetypes::tar_map_rep()
      → topic-hybrid-branching.md

Encapsulating a reusable multi-target pattern?
  └─► TARGET FACTORY: tar_target_raw()
      → topic-target-factories.md
```

## Approach Comparison

| Aspect | Static | Dynamic | Hybrid |
|--------|--------|---------|--------|
| When defined | Before `tar_make()` | During `tar_make()` | Both |
| Target names | Friendly (`analysis_bayesian`) | Hashed (`analysis_3a7f2b`) | Mixed |
| Scale | <1000 targets | 100k+ targets | Moderate |
| Validation | Full `tar_manifest()` | Must run to see branches | Partial |
| Use case | Method comparison | Simulations, file processing | Methods x replications |

## Static Branching Overview

Use `tarchetypes::tar_map()` when iterations are known at define-time and you want readable target names.

```r
values <- tibble::tibble(
  method = rlang::syms(c("analyze_bayesian", "analyze_freq")),
  method_name = c("bayesian", "freq")
)

tarchetypes::tar_map(
  values = values,
  names = "method_name",
  targets::tar_target(result, method(data)),
  targets::tar_target(summary, summarize_result(result))
)
# Creates: result_bayesian, result_freq, summary_bayesian, summary_freq
```

Aggregate with `tarchetypes::tar_combine()`:

```r
mapped <- tarchetypes::tar_map(
  unlist = FALSE,
  values = values,
  targets::tar_target(result, method(data))
)

tarchetypes::tar_combine(
  all_results,
  mapped[["result"]],
  command = dplyr::bind_rows(!!!.x, .id = "method")
)
```

**Key points:**
- Function names must be symbols: use `rlang::syms()`, not strings
- Use `unlist = FALSE` when you need `tar_combine()` afterward
- `!!!.x` splices the list of upstream results into the command

See [topic-static-branching.md](topic-static-branching.md) for details on `tar_eval()`, `tar_sub()`, and complex value construction.

## Dynamic Branching Overview

Use the `pattern` argument when branch count depends on data or you need massive scale.

```r
list(
  targets::tar_target(datasets, c("trial_A", "trial_B", "trial_C")),
  targets::tar_target(
    analysis,
    analyze_data(datasets),
    pattern = map(datasets)
  )
)
```

**Pattern types:**
- `map(x, y)` - parallel iteration (zip)
- `cross(x, y)` - cartesian product
- `slice(x, index = c(1, 3))` - specific elements
- `head(x, n = 5)` / `tail()` / `sample()` - subsets

**Critical:** Patterns reference *target names*, not R objects or expressions.

```r
# WRONG: Can't reference external objects
my_vec <- 1:5
targets::tar_target(x, process(my_vec), pattern = map(my_vec))

# CORRECT: Reference upstream target by name
list(
  targets::tar_target(params, 1:5),
  targets::tar_target(result, process(params), pattern = map(params))
)
```

See [topic-dynamic-branching.md](topic-dynamic-branching.md) for iteration modes, row grouping, and batching.

## Hybrid Patterns Overview

Combine static branching (for methods/variants) with dynamic branching (for replications):

```r
values <- tibble::tibble(
  method = rlang::syms(c("method_a", "method_b")),
  method_name = c("a", "b")
)

tarchetypes::tar_map_rep(
  name = sim_result,
  command = method(simulate_data()),
  values = values,
  names = "method_name",
  batches = 10,

  reps = 100
)
```

See [topic-hybrid-branching.md](topic-hybrid-branching.md) for complete patterns.

## Target Factories Overview

A target factory is a function that returns pre-configured target objects:

```r
#' @export
analyze_dataset <- function(name, file_path) {
  name <- targets::tar_deparse_language(substitute(name))
  name_data <- paste0(name, "_data")
  sym_data <- as.symbol(name_data)

  command <- substitute(analyze(data), env = list(data = sym_data))

  list(
    targets::tar_target_raw(name_data, substitute(load_csv(file_path))),
    targets::tar_target_raw(name, command)
  )
}
```

See [topic-target-factories.md](topic-target-factories.md) for metaprogramming patterns and validation.

## Debugging and Troubleshooting

### Validation Commands

```r
# Check target definitions before running
targets::tar_manifest()
targets::tar_manifest(fields = c("name", "command", "pattern"))

# Visualize DAG (slow with many targets)
targets::tar_visnetwork(targets_only = TRUE)

# Test pattern logic without running pipeline
targets::tar_pattern(
  cross(method, map(dataset, seed)),
  method = 3,
  dataset = 5,
  seed = 10
)
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Target 'x' not found" in pattern | Pattern references non-existent target | Check spelling; ensure upstream target exists |
| "object 'x' not found" in command | External object in pattern | Create upstream target; patterns reference target names only |
| Strings not callable | Using `c("func_a", "func_b")` | Use `rlang::syms()` for function names |
| Can't selectively combine | Missing `unlist = FALSE` | Add to `tar_map()` when using `tar_combine()` |
| Cryptic target names | Dynamic branching default | Add metadata to output or use static branching |

### Identifying Failed Branches

```r
# Check which targets have errors
targets::tar_meta() |>
  dplyr::filter(error != "")

# Read specific branch by index
targets::tar_read(target_name, branches = 1)

# Inspect all branch metadata
targets::tar_branches(target_name)
```

### Debugging Strategies

1. **Start with `tar_manifest()`** - verify target count and commands before running
2. **Test with subset** - use `pattern = head(x, n = 3)` for initial runs
3. **Include provenance** - add parameter values to branch outputs for traceability
4. **Check upstream first** - use `tar_read()` on dependencies before investigating branching

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| `pattern = map(df$col)` | Can't reference external objects | Create upstream target |
| `method = c("fn_a", "fn_b")` | Strings aren't callable | `rlang::syms(c("fn_a", "fn_b"))` |
| Manual `lapply` + aggregation | Reinventing batching | Use `tar_rep()` or `tar_map_rep()` |
| `tar_make()` without validation | Errors discovered late | Always `tar_manifest()` first |
| `expand_grid()` with `syms()` inside | `syms()` doesn't expand in grid | Apply `syms()` after grid creation |

## See Also

- **r-metaprogramming**: Expression manipulation for target factories
- **tidy-evaluation**: Programming with data-masked functions
- [targetopia-packages.md](targetopia-packages.md): Package development workflows

## Reference Files

- [topic-static-branching.md](topic-static-branching.md) - Full static branching guide
- [topic-dynamic-branching.md](topic-dynamic-branching.md) - Full dynamic branching guide
- [topic-hybrid-branching.md](topic-hybrid-branching.md) - Dynamic within static patterns
- [topic-target-factories.md](topic-target-factories.md) - Custom factory functions
- [references/tarchetypes-functions.md](references/tarchetypes-functions.md) - Function reference
- [references/pattern-composition.md](references/pattern-composition.md) - Pattern algebra
- [references/targets-utilities.md](references/targets-utilities.md) - Package author utilities
- [templates/static-branching.R](templates/static-branching.R) - Static branching code template
- [templates/target-factory.R](templates/target-factory.R) - Target factory code template
- [targetopia-packages.md](targetopia-packages.md) - Targetopia package development guide

## External Resources

- [targets documentation](https://docs.ropensci.org/targets)
- [tarchetypes package](https://docs.ropensci.org/tarchetypes)
- [targets manual: dynamic branching](https://books.ropensci.org/targets/dynamic.html)
- [targets manual: static branching](https://books.ropensci.org/targets/static.html)
