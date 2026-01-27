# r-skills

Claude Code plugin providing skills for R programming. Complementary to [Posit skills](https://github.com/posit-dev/skills).

## Installation

### Via Marketplace (recommended)

```
/plugin marketplace add jsperger/llm-r-skills
/plugin install r-skills@r-skills
```

### Local Development

```bash
claude --plugin-dir /path/to/r-skills
```

### Dependencies

For full functionality, the following are required:

- [languageserver](https://github.com/REditorSupport/languageserver) - R package for LSP support
- [jq](https://jqlang.org/download/) - JSON processor for hooks
- [air](https://github.com/posit-dev/air) - R code formatter

## Skills

### [designing-tidy-r-functions](skills/designing-tidy-r-functions)
Guidelines for designing user-friendly R function APIs, covering naming conventions, argument ordering, and output stability.

### [ggplot2](skills/ggplot2)
ggplot2 4.0+ features including S7 migration, theme defaults, and new scale/position aesthetics.

### [hardhat](skills/hardhat)
Infrastructure for building `tidymodels`-compatible modeling packages using `mold()` and `forge()`.

### [r-languageserver](skills/r-languageserver)
Instructions for using the language server and avoiding common agent operator pitfalls such as not positioning the cursor on a symbol.

### [metaprogramming](skills/metaprogramming)
Techniques for manipulating R expressions using `rlang`: defuse-and-inject pattern, quosures, and symbol construction.

### [rlang-conditions](skills/rlang-conditions)
Error handling with `rlang` and `cli`: formatted output, error chaining, and input validation.

### [targets-pipelines](skills/targets-pipelines)
Complex `targets` patterns: static branching, dynamic branching, hybrid patterns, and custom target factories. 

This is a work-in-progress and doesn't cover basic `targets` functionality; it's targeted to some pain points I've kept running into trying to get LLMs to write target definitions. It covers branching and a few of the `tarchetypes` branching-related target factories. 

### [tidy-evaluation](skills/tidy-evaluation)
Programming patterns for data-masked functions in the tidyverse using `{{}}` and managing variable ambiguity.



### [tidymodels-overview](skills/tidymodels-overview)
Overview of the tidymodels ecosystem for machine learning in R.


