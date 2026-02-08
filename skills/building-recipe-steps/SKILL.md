---
name: building-recipe-steps
description: This skill provides reference material for building custom recipe steps for the recipes package in R. It is loaded by the recipe-step-builder agent. Contains templates, a development checklist, and implementation guidance for the S3 class structure required by custom `step_*()` functions.
---

# Building Custom Recipe Steps

## Overview

Custom recipe steps extend the recipes package with new preprocessing operations. Each step follows the recipes S3 class structure: a constructor, initializer, prep method, bake method, and supporting methods (print, tidy, required_pkgs).

## Required S3 Methods

Every custom step requires these seven components:

| Component | Function | Purpose |
|-----------|----------|---------|
| Constructor | `step_{name}()` | User-facing function; stores arguments, calls `add_step()` |
| Initializer | `step_{name}_new()` | Internal; creates the S3 object via `recipes::step()` |
| Prep | `prep.step_{name}()` | Estimate parameters from training data |
| Bake | `bake.step_{name}()` | Apply transformation to new data |
| Print | `print.step_{name}()` | Display step summary |
| Tidy | `tidy.step_{name}()` | Extract step metadata as a tibble |
| Required pkgs | `required_pkgs.step_{name}()` | Declare dependencies for parallel backends |

## Key Design Rules

- **Constructor stores, never computes.** The constructor captures variable selectors via `enquos(...)` and passes them to the initializer. No data processing occurs here.
- **Prep estimates from training data only.** Use `recipes::recipes_eval_select()` to resolve selectors, `recipes::check_type()` to validate types, and store estimated parameters as named fields on the returned step object.
- **Bake applies stored parameters.** Use `recipes::check_new_data()` to verify columns exist, apply transformations using only the parameters stored during prep, and return a tibble.
- **Row count is invariant.** Unless the step is specifically for filtering (`skip = TRUE`), `bake()` must return the same number of rows as `new_data`.

## Tunable Parameters

For steps with hyperparameters that should integrate with `tune::tune()`:

1. Define a `tunable.step_{name}()` method
2. Return a tibble mapping each parameter to a `dials` function
3. Mark tunable parameters with `tune()` as the default in the constructor

## Resources

### Templates

- **`templates/STEP_TEMPLATE.R`** — Complete step implementation scaffold with roxygen2 documentation. Replace `STEPNAME`, `ACTIONDESC`, `ACTIONDESC_LOWER`, and `PKGNAME` placeholders.
- **`templates/TEST_TEMPLATE.R`** — testthat test suite scaffold. Replace `STEPNAME` placeholder.

### Reference

- **`reference/CHECKLIST.md`** — Development checklist covering all required methods, integration tests, and optional tunable parameter support.
- **`reference/testing-recipe-steps.md`** — Comprehensive guide to writing testthat tests for custom steps, covering all test categories (round-trip, correctness, selectors, workflow integration, edge cases) with code examples and expectations reference.
