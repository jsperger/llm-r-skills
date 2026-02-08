---
name: recipes-feature-engineering
description: This skill should be used when writing feature engineering or preprocessing code with the recipes package as part of a tidymodels pipeline. Applicable when the user asks to "build a recipe", "add preprocessing steps", "create a recipe for my workflow", "feature engineering with recipes", "step ordering", "handle missing values in a recipe", "encode categorical variables", "normalize predictors", or when using recipe functions like recipe(), step_normalize(), step_dummy(), step_impute_*, prep(), bake() within a tidymodels workflow. Does NOT cover custom step development (see building-recipe-steps skill).
---

# Feature Engineering with recipes in Tidymodels

The recipes package defines preprocessing as a specification that integrates into tidymodels workflows. A recipe is a **plan**, not an action — transformations execute only when `prep()` estimates parameters and `bake()` applies them.

## The Define-Prep-Bake Lifecycle

### 1. Define (Specification)

Initialize a recipe from a formula and training data, then append steps:

```r
rec <- recipe(outcome ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_normalize(all_numeric_predictors())
```

No calculations occur. The recipe stores the sequence of operations and variable selectors.

### 2. Prep (Estimation)

Estimate parameters from training data only:

```r
prepped <- prep(rec, training = train_data)
```

Each step resolves its selectors and computes statistics (means, standard deviations, factor levels). **Never prep with test data** — this causes data leakage.

### 3. Bake (Application)

Apply the prepped recipe to data:

```r
train_processed <- bake(prepped, new_data = NULL)   # training data
test_processed  <- bake(prepped, new_data = test_data)
```

`bake(new_data = NULL)` returns the preprocessed training data used during prep.

## Using Recipes in Workflows

In practice, avoid calling `prep()` and `bake()` directly. Bundle the recipe into a workflow and let tidymodels manage the lifecycle:

```r
wflow <- workflow() |>
  add_recipe(rec) |>
  add_model(model_spec)

# fit() calls prep() + bake() internally
fitted <- fit(wflow, data = train_data)

# predict() calls bake() on new data automatically
predictions <- predict(fitted, new_data = test_data)
```

Direct `prep()`/`bake()` is appropriate only for:
- Inspecting preprocessed data during development
- Standalone preprocessing outside a modeling pipeline
- Debugging recipe behavior

## Variable Selection

Use tidyselect helpers inside `step_*()` calls. Avoid hardcoding column names.

### By Role
- `all_predictors()`, `all_outcomes()` — assigned during `recipe()`
- `has_role("custom_role")` — match custom roles

### By Type
- `all_numeric_predictors()`, `all_nominal_predictors()` — type AND role
- `all_numeric()`, `all_nominal()` — type only
- `all_double()`, `all_integer()`, `all_factor()`, `all_string()`
- `all_date()`, `all_datetime()`

### Combining Selectors

```r
step_normalize(all_numeric_predictors(), -skip_col)
step_dummy(all_nominal_predictors(), -has_role("id"))
```

## Roles

Variables receive roles from the recipe formula (`predictor`, `outcome`). Assign custom roles for columns that should travel through the pipeline but not participate in modeling:

```r
rec <- recipe(outcome ~ ., data = train_data) |>
  update_role(patient_id, new_role = "id")
```

Columns with custom roles are excluded from `all_predictors()` but available in `bake()` output.

### Role Requirements and step_rm()

Custom roles are required at bake time by default. When removing columns with custom roles, mark the role as optional first:

```r
rec <- recipe(outcome ~ ., data = train_data) |>
  update_role(patient_id, new_role = "id") |>
  update_role_requirements("id", bake = FALSE) |>
  step_rm(has_role("id"))
```

Without `update_role_requirements()`, baking new data that lacks the removed column will error.

## Step Ordering

Order matters. Follow this sequence for statistical validity:

1. **Imputation** — Fix missing values first so downstream steps have complete data
   - `step_impute_mean()`, `step_impute_median()`, `step_impute_knn()`, `step_impute_bag()`
2. **Individual transformations** — Log, Box-Cox, Yeo-Johnson
   - `step_log()`, `step_BoxCox()`, `step_YeoJohnson()`, `step_mutate()`
3. **Discretization** — Convert numeric to categorical (if needed)
   - `step_discretize()`, `step_cut()`
4. **Factor level handling** — Collapse rare levels and handle unseen levels before encoding
   - `step_other()`, `step_novel()`
5. **Dummy encoding** — Convert factors to numeric indicators. Must precede normalization.
   - `step_dummy()`
6. **Interaction terms** — Create products of numeric predictors
   - `step_interact()`
7. **Normalization** — Center and scale. Requires numeric input.
   - `step_normalize()`, `step_center()`, `step_scale()`, `step_range()`
8. **Multivariate transformations** — PCA, ICA, embeddings
   - `step_pca()`, `step_ica()`, `step_pls()`
9. **Filtering** — Remove zero-variance or highly correlated columns
   - `step_zv()`, `step_nzv()`, `step_corr()`

## Common Recipes by Task

### Classification with Mixed Types

```r
recipe(class ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_novel(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors())
```

### Regression with Skewed Predictors

```r
recipe(price ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>
  step_YeoJohnson(all_numeric_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_corr(all_numeric_predictors(), threshold = 0.9)
```

### High-Cardinality Categoricals

```r
recipe(outcome ~ ., data = train) |>
  step_other(all_nominal_predictors(), threshold = 0.05) |>
  step_novel(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors())
```

## Anti-Patterns

- **Skipping prep()**: `bake(recipe(...), new_data = x)` fails — the recipe is not trained.
- **Prepping with all data**: `prep(rec, training = full_data)` before splitting leaks test information.
- **Hardcoding column names**: Use `all_numeric_predictors()` instead of `c("col1", "col2")`.
- **Normalizing before encoding**: `step_normalize()` before `step_dummy()` skips the new indicator columns.
- **Modifying internals**: Never access `recipe$steps[[i]]$means` directly. Use `tidy()` to inspect step parameters.

## Additional Resources

### Reference Files

- **`examples.md`** — Standalone recipe example with the credit_data dataset
- **`references/pipeline-examples.md`** — Complete tidymodels pipeline examples showing recipes within workflows, tuning, and model comparison

### Related Skills

- **tidymodels-overview** — Ecosystem context and standard workflow
- **building-recipe-steps** — Reference for developing custom `step_*()` functions
- **hardhat** — Internal preprocessing infrastructure (mold/forge/blueprints)
