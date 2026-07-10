# r-skills

Claude Code plugin providing skills for R programming. Complementary to [Posit skills](https://github.com/posit-dev/skills).

## Installation

### Via Marketplace (recommended)

After pushing to GitHub:

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

## Using the plugin effectively

- **Formatting is automatic.** A hook runs `air format` after every file edit. Never
  ask Claude to fix style or formatting — it is already done, and the language server
  is configured not to compete with it.
- **Lint diagnostics are correctness-only by default.** In a project with no
  `.lintr`/`.lintr.R`, the language server lints with the plugin's slim profile
  ([`config/agent.lintr`](config/agent.lintr)): object-usage errors, missing packages,
  `== NA` comparisons, and similar real bugs — no line-length or spacing noise burning
  context. If your project ships its own `.lintr`, it always wins, and Claude sees
  exactly the lints your CI sees.
- **Something not working?** Run `/r-lsp-diagnose`. It checks the toolchain end to
  end, including the languageserver/lintr version combination that silently disables
  `.lintr` files.

## Skills

### [designing-tidy-r-functions](skills/designing-tidy-r-functions)
Guidelines for designing user-friendly R function APIs, covering naming conventions, argument ordering, and output stability.

### [ggplot2](skills/ggplot2)
ggplot2 4.0+ features including S7 migration, theme defaults, and new scale/position aesthetics.

### [hardhat](skills/hardhat)
Infrastructure for building `tidymodels`-compatible modeling packages using `mold()` and `forge()`.

### [metaprogramming](skills/metaprogramming)
Techniques for manipulating R expressions using `rlang`: defuse-and-inject pattern, quosures, and symbol construction.

### [r-languageserver](skills/r-languageserver)
Using the R language server to navigate code: find definitions and references, understand call hierarchies, and run impact analysis before refactoring. Helps Claude discover LSP functionality the plugin alone did not surface.

### [rlang-conditions](skills/rlang-conditions)
Error handling with `rlang` and `cli`: formatted output, error chaining, and input validation.

### [targets-pipelines](skills/targets-pipelines)
Complex `targets` patterns: static branching, dynamic branching, hybrid patterns, and custom target factories.

### [tidy-evaluation](skills/tidy-evaluation)
Programming patterns for data-masked functions in the tidyverse using `{{}}` and managing variable ambiguity.

### [tidymodels-overview](skills/tidymodels-overview)
Overview of the tidymodels ecosystem for machine learning in R.

## Commands

### `/r-lsp-diagnose`
Diagnose R language server connectivity and configuration, and suggest fixes. Runs `scripts/lsp-test-harness.sh`, which exercises core LSP functionality and reports results as JSON (pass `--fix` to attempt repairs).
