---
name: tidymodels-overview
description: >
Understand the R tidymodels package ecosystem. This skill should be used when working with R tidymodels packages, including when the user asks to "create a tidymodels workflow", "build a recipe", "tune a model", "use parsnip", "set up resampling", "create a workflow_set", "compare models", "stack models", or mentions tidymodels packages like recipes, parsnip, workflows, workflowsets, tune, rsample, yardstick, or stacks. 
version: "0.2.0"

---

# Tidymodels Overview

The tidymodels ecosystem provides a consistent, modular framework for machine learning in R. Understanding the ecosystem context helps when working with any tidymodels pipeline before diving into package-specific details.

## Core Principle: Recipes Are Plans, Not Actions

**Critical**: A `recipe` object is a *specification* of preprocessing steps. Adding steps like `step_normalize()` does **not** transform data immediately. Transformations execute only when:

1. `prep()` estimates parameters from training data
2. `bake()` applies the prepped recipe to new data

```r
# This does NOT transform data - it creates a plan
rec <- recipe(outcome ~ ., data = train) |>
  step_normalize(all_numeric_predictors())

# This estimates parameters (means, sds) from training data
prepped <- prep(rec, training = train)

# This applies transformations to new data
processed <- bake(prepped, new_data = test)
```

## The Tidymodels Workflow

Follow this standard workflow for modeling projects:

### 1. Data Splitting (rsample)

Allocate data to training, validation, and test sets before any modeling:

```r
set.seed(123)
data_split <- initial_split(data, prop = 0.8, strata = outcome)
train_data <- training(data_split)
test_data  <- testing(data_split)

# For iterative evaluation during development
resamples <- vfold_cv(train_data, v = 10)
```

### 2. Preprocessing (recipes)

Define feature engineering as a recipe specification:

```r
rec_spec <- recipe(outcome ~ ., data = train_data) |>
  step_normalize(all_numeric_predictors()) |>
  step_dummy(all_factor_predictors()) |>
  step_zv(all_predictors())
```

Use tidyselect helpers for column selection:
- `all_predictors()`, `all_outcomes()` - by role
- `all_numeric_predictors()`, `all_nominal_predictors()` - by type and role
- `has_role()`, `has_type()` - explicit queries

### 3. Model Specification (parsnip)

Define the model type, engine, and mode separately from fitting:

```r
model_spec <- rand_forest(mtry = tune(), trees = 1000) |>
  set_engine("ranger") |>
  set_mode("regression")
```

### 4. Bundling (workflows)

Combine preprocessing and model into a single object:

```r
wflow <- workflow() |>
  add_recipe(rec_spec) |>
  add_model(model_spec)
```

### 5. Evaluation (tune + yardstick)

Use resampling or validation sets to assess performance:

```r
# Define metrics
metrics <- metric_set(rmse, rsq, mae)

# Tune hyperparameters
tuned <- tune_grid(
  wflow,
  resamples = resamples,
  grid = 10,
  metrics = metrics
)

# Select best parameters
best_params <- select_best(tuned, metric = "rmse")
```

### 6. Finalization

Finalize the workflow and fit to full training data:

```r
final_wflow <- finalize_workflow(wflow, best_params)
final_fit <- last_fit(final_wflow, split = data_split)

# Extract test set metrics
collect_metrics(final_fit)
```

## Package Roles

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **rsample** | Data splitting and resampling | `initial_split()`, `vfold_cv()`, `bootstraps()` |
| **recipes** | Preprocessing specification | `recipe()`, `step_*()`, `prep()`, `bake()` |
| **parsnip** | Model specification | Model functions, `set_engine()`, `set_mode()` |
| **workflows** | Bundle recipe + model | `workflow()`, `add_recipe()`, `add_model()` |
| **tune** | Hyperparameter optimization | `tune_grid()`, `tune_bayes()`, `select_best()` |
| **yardstick** | Performance metrics | `metric_set()`, `rmse()`, `accuracy()` |
| **workflowsets** | Compare multiple pipelines | `workflow_set()`, `workflow_map()` |
| **stacks** | Model ensembling | `stacks()`, `add_candidates()`, `blend_predictions()` |
| **hardhat** | Internal infrastructure | `mold()`, `forge()`, blueprints |

## Key Principles

### Use Package Functions, Not Direct Access

Never directly modify tidymodels object internals. Always use provided functions:

```r
# WRONG - directly modifying internals
recipe_obj$steps[[1]]$means <- new_means

# CORRECT - use proper functions
rec <- recipe(...) |>
  step_normalize(...) |>
  prep()
```

### Use Selectors, Not String Matching

Avoid constructing variable lists manually:

```r
# WRONG - manual string matching
numeric_cols <- names(data)[sapply(data, is.numeric)]
rec |> step_normalize(all_of(numeric_cols))

# CORRECT - use tidyselect helpers
rec |> step_normalize(all_numeric_predictors())
```

### Understand Role Requirements

Custom roles are required at `bake()` time by default. When using `step_rm()` with custom roles, update requirements:

```r
rec <- recipe(...) |>
  update_role(id_column, new_role = "id") |>
  update_role_requirements("id", bake = FALSE) |>
  step_rm(has_role("id"))
```

### workflowsets Require Same Outcome

All workflows in a `workflow_set` must predict the same outcome variable. For different outcomes, create separate workflow sets.

## When to Use Each Package

- **Simple model**: recipes + parsnip + workflows
- **Hyperparameter tuning**: Add tune
- **Model comparison**: Add workflowsets
- **Ensemble models**: Add stacks (requires `save_pred = TRUE`, `save_workflow = TRUE`)
- **Custom preprocessing interfaces**: Use hardhat

## Additional Resources

### Reference Files

For detailed information, consult:

- **`references/packages.md`** - Detailed package documentation including object structures, creation processes, and deep knowledge links
- **`references/common-problems.md`** - Common pitfalls when working with tidymodels and how to avoid them

### External Documentation

- [tidymodels.org](https://www.tidymodels.org) - Official documentation and tutorials
- [recipes.tidymodels.org](https://recipes.tidymodels.org) - Recipe step reference
- [parsnip.tidymodels.org](https://parsnip.tidymodels.org) - Model specifications
