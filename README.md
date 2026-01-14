# Agent Skills for R programming
Complementary to [Posit skills](https://github.com/posit-dev/skills)

## Skills

### [designing-tidy-r-functions](designing-tidy-r-functions)
**Status**: Alpha

Guidelines for designing user-friendly R function APIs, covering naming conventions, argument ordering, and output stability. Focuses on reducing cognitive load and ensuring composability. This assumes you are using a linter and code formatter. 

### [hardhat](hardhat)
**Status**: Alpha

Infrastructure for building `tidymodels`-compatible modeling packages. Standardizes preprocessing via `mold()` and `forge()` to handle formula, matrix, and recipe inputs uniformly.

### [metaprogramming](metaprogramming)
**Status**: Alpha

Techniques for manipulating R expressions and building code programmatically using `rlang`. Covers the defuse-and-inject pattern, quosures, and symbol construction.

### [rlang-conditions](rlang-conditions)
**Status**: Alpha

Best practices for handling errors and messages using `rlang` and `cli`. Includes patterns for formatted output, error chaining, and informative input checkers.

### [targets-pipelines](targets-pipelines)
**Status**: Alpha

Complex `targets` pipeline patterns including static branching (`tar_map`/`tar_combine`), dynamic branching (`pattern` argument), hybrid patterns (`tar_map_rep`), and custom target factories. Includes decision tree, debugging guide, and templates.

### [tidy-evaluation](tidy-evaluation)
**Status**: Alpha

Programming patterns for data-masked functions in the tidyverse. Details how to safely pass column references with `{{}}` and manage variable ambiguity.
