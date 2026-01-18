# r-skills

Claude Code plugin providing skills for R programming. Complementary to [Posit skills](https://github.com/posit-dev/skills).

## Installation

```bash
claude --plugin-dir /path/to/r-skills
```

Or add to your Claude Code settings.

## Skills

### [designing-tidy-r-functions](skills/designing-tidy-r-functions)
Guidelines for designing user-friendly R function APIs, covering naming conventions, argument ordering, and output stability.

### [ggplot2](skills/ggplot2)
ggplot2 4.0+ features including S7 migration, theme defaults, and new scale/position aesthetics.

### [hardhat](skills/hardhat)
Infrastructure for building `tidymodels`-compatible modeling packages using `mold()` and `forge()`.

### [metaprogramming](skills/metaprogramming)
Techniques for manipulating R expressions using `rlang`: defuse-and-inject pattern, quosures, and symbol construction.

### [rlang-conditions](skills/rlang-conditions)
Error handling with `rlang` and `cli`: formatted output, error chaining, and input validation.

### [targets-pipelines](skills/targets-pipelines)
Complex `targets` patterns: static branching, dynamic branching, hybrid patterns, and custom target factories.

### [tidy-evaluation](skills/tidy-evaluation)
Programming patterns for data-masked functions in the tidyverse using `{{}}` and managing variable ambiguity.

### [tidymodels-overview](skills/tidymodels-overview)
Overview of the tidymodels ecosystem for machine learning in R.
