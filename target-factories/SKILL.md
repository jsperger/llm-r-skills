---
name: target factories
description: >
  Write R functions extending the targets workflow framework (target factories), or implement static/dynamic branching patterns for targets. 
dependencies: R>=4.3, targets>=1.6.0
---

## Overview

This skill explains how to extend
[`targets`](https://docs.ropensci.org/targets), a Make-like pipeline tool for R,
by writing target factories. Target factories are functions that generate lists of
pre-configured target definition objects from simple user inputs. Use [targetopia-packages.md](targetopia packages) for package development workflows.

Use cases
- writing branching targets
  + static branching with map / combine
  + dynamic branching via `pattern` argument to `tar_target`
  + recombining dynamic branches
  + dynamic within static branching
- writing target factory functions
- writing packages that extend targets
- map / combine

## Quick Reference

| Task | Function/Pattern |
|------|------------------|
| Create target in factory | `tar_target_raw(name, command, ...)` |
| Quote an expression | `quote(f(x))` |
| Expression to string | `deparse(quote(f(x)))` |
| Insert values into expression | `substitute(f(arg), env = list(arg = value))` |
| String to symbol | `as.symbol("name")` |
| Static branching | `tarchetypes::tar_map()` |
| Dynamic branching | `targets::tar_target(..., pattern = map(...))` |

### tar_target_raw() vs tar_target()

| Aspect | `tar_target()` | `tar_target_raw()` |
|--------|----------------|-------------------|
| Audience | End users | Package developers |
| Name argument | Symbol | Character string |
| Command argument | Expression | Quoted expression |
| Pattern argument | Expression | Quoted expression |

## Choosing between static and dynamic branching
Static branching defines the iteration space at configuration time (parsing targets source script); dynamic branching defines configuration at run time. Dynamic branching can be used within static branching. 

```
Iteration space known before `tar_make()`?
├── No: Dynamic 
└── Yes: Heterogeneous tasks?
    ├── Yes: Static 
    └── No: Large scale?
        ├── Yes: Dynamic 
        └── No: Named nodes in DAG needed?
            ├── Yes: Static 
            └── No: Dynamic 
```

### Static Branching (tar_map)

* Mechanism: Metaprogramming; expands `_targets.R` during parsing.
* Use Case: Small, distinct sets (e.g., comparing specific model architectures).
* Pro: Every branch is a unique node in tar_visnetwork().

### Dynamic Branching (`pattern` arg to `targets::tar_target`)

* Mechanism: Runtime dispatch; branches created after upstream completion.
* Use Case: High-throughput (simulations), data-driven partitioning.
* Pro: Concise script & DAG; handles (N) branches where (N) is unknown at configuration.

## Target Factory Pattern

A target factory is a function that accepts simple inputs, calls [`tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target_raw.html), and produces a list of configured target definition objects:

```r
#' @export
fit_model_to_data <- function(name, file) {
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
    targets::tar_target_raw(name_file, file, format = "file", deployment = "main"),
    targets::tar_target_raw(name_data, command_data, format = "fst_tbl"),
    targets::tar_target_raw(name_model, command_model, format = "qs")
  )
}
```

User writes one call instead of multiple `tar_target()` calls:

```r
# _targets.R
library(targets)
library(yourPackage)
fit_model_to_data(custom_model, "data.csv")
```

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

## Target factories should pre-configure settings using domain knowledge

Pre-configure arguments users shouldn't worry about.

## See Also

- **r-metaprogramming**: Expression manipulation fundamentals
- **designing-tidy-r-functions**: Function API design
- **testing-r-packages**: Testing patterns

## External Resources

- [targets documentation](https://docs.ropensci.org/targets)
- [tarchetypes package](https://docs.ropensci.org/tarchetypes) - Targetopia package containing a collection of target and pipeline archetypes
- [stantargets](https://docs.ropensci.org/stantargets) - Example domain-specific Targetopia package
- [rOpenSci software review](https://devguide.ropensci.org/softwarereviewintro.html)
