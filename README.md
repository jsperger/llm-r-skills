# r-skills

Claude Code plugin providing skills, commands, and agents for R programming. Complementary to [Posit skills](https://github.com/posit-dev/skills).

## Features

- **Skills**: Domain knowledge for tidyverse patterns, package development, rlang, targets, and more
- **Commands**: Slash commands for fixing tests, adding tests, and LSP diagnostics
- **Agents**: Autonomous agents for test fixing and roxygen2 documentation
- **Hooks**: Automatic R code formatting, documentation, and testing before commits/PRs

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
- [lintr](https://lintr.r-lib.org/) - R linter for diagnostics
- [jq](https://jqlang.org/download/) - JSON processor for hooks
- [air](https://github.com/posit-dev/air) - R code formatter

Install R packages:
```r
install.packages(c("languageserver", "lintr", "devtools", "testthat"))
```

## Commands

### `/r-fix-tests [package-path]`
Diagnose and fix failing R package tests. Runs the test suite, analyzes failures, and implements fixes.

### `/r-add-tests [file-or-function]`
Add testthat tests for an R function or file. Analyzes the code and generates comprehensive test coverage.

### `/r-lsp-diagnose`
Test R Language Server connectivity and diagnose issues. Checks R installation, languageserver package, and configuration.

## Agents

### test-fixer
Autonomous agent for diagnosing and fixing failing tests. Triggers on:
- "my tests are failing"
- "commit was blocked because of test failures"
- Specific test file errors

### roxygen-documenter
Agent for writing roxygen2 documentation. Triggers on:
- "add documentation to this function"
- "write roxygen comments"
- "update the documentation"

### recipe-step-builder
Scaffolds and implements custom `step_*()` functions for the recipes package. Triggers on:
- "create a custom recipe step"
- "add a step_lag() to my package"
- "my custom recipe step isn't working"

### recipe-step-tester
Writes comprehensive testthat test suites for custom recipe steps. Triggers on:
- "write tests for my step_winsorize()"
- "my step tests need better coverage"
- "add tests for the step we just created"

## Hooks

### Pre-commit Workflow
Before `git commit` or `gh pr create`:
1. Format all R files with `air`
2. Run `devtools::document()` on packages with R/ changes
3. Run `devtools::test()` on affected packages

**Behavior:**
- Commits: Warn on test failures (allow commit to proceed)
- PRs: Block if tests fail

### Post-edit Workflow
After editing R files (Write|Edit):
1. Format with `air`
2. Lint with `lintr`

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



### [building-recipe-steps](skills/building-recipe-steps)
Reference for developing custom `step_*()` functions for the recipes package. Includes implementation templates, test templates, and a development checklist. Loaded by the `recipe-step-builder` agent.

### [recipes-feature-engineering](skills/recipes-feature-engineering)
Feature engineering with recipes in tidymodels pipelines: define-prep-bake lifecycle, variable selection, roles, step ordering, and common recipe patterns.

### [tidymodels-overview](skills/tidymodels-overview)
Overview of the tidymodels ecosystem for machine learning in R.

### [r-package-development](skills/r-package-development)
R package development workflows: devtools, testthat 3 patterns, roxygen2 documentation, usethis helpers, and monorepo organization.

### [s7-objects](skills/s7-objects)
Creating R classes, generics, and methods with the S7 object system. Covers `new_class()`, `new_generic()`, `method()`, typed properties, validators, custom constructors, `super()` dispatch, and S3/S4 interoperability.
