# Common Problems When Working with Tidymodels

This reference documents frequently observed problems when working with tidymodels packages and how to avoid them.

## General Problems

### Directly Modifying Internals

**Problem**: Directly accessing tidymodels objects by modifying lists and changing attributes instead of using proper constructors, accessors, and functions.

**Why this is bad**:
- Bypasses validation that package functions provide
- Creates brittle code that breaks when internal representations change
- Violates encapsulation principles

**Wrong approach**:
```r
# Directly modifying recipe internals
recipe_obj$steps[[1]]$means <- new_means
recipe_obj$var_info$role[3] <- "outcome"

# Directly modifying workflow internals
workflow_obj$fit$fit$fit <- new_model
```

**Correct approach**:
```r
# Use proper functions to create new objects
rec <- recipe(...) |>
  step_normalize(...) |>
  prep()

# Use extraction functions
extract_fit_engine(workflow_fit)
extract_recipe(workflow_fit)
```

### Ignoring Package Functions / Writing Custom Implementations

**Problem**: Writing custom functions for operations that tidymodels packages already provide, especially for common tasks like variable selection, data extraction, or model evaluation.

**Why this is bad**:
- Custom implementations miss edge cases that package authors have handled
- Creates maintenance burden when tidymodels updates
- Often less efficient than optimized package functions

**Examples of reinventing the wheel**:
```r
# WRONG - custom extraction
my_data <- workflow_obj$pre$mold$predictors

# CORRECT - use extraction function
my_data <- extract_mold(workflow_fit)$predictors
```

---

## recipes Package Problems

### Expecting Immediate Changes After Adding Steps

**Problem**: Expecting data to be transformed immediately after adding a step to a recipe.

**Why this happens**: Misunderstanding that recipes are a *plan* and don't execute until `prep()` and `bake()`.

**Wrong understanding**:
```r
rec <- recipe(y ~ ., data = train) |>
  step_normalize(all_numeric_predictors())

# Expecting 'rec' to now contain normalized data - IT DOES NOT
```

**Correct understanding**:
```r
# Recipe is just a specification
rec <- recipe(y ~ ., data = train) |>
  step_normalize(all_numeric_predictors())

# prep() estimates parameters (means, sds) from training data
prepped <- prep(rec, training = train)

# bake() applies the transformations
normalized_train <- bake(prepped, new_data = NULL)
normalized_test  <- bake(prepped, new_data = test)
```

**Exception**: `update_role()` and `update_role_requirements()` immediately update the recipe; these are distinct from `step_*` functions.

### Writing Custom Variable Selection Logic

**Problem**: Constructing lists of variable names with string matching (e.g., `grepl`) and type checking instead of using tidyselect helpers.

**Wrong approach**:
```r
# Manual string matching for numeric predictors
numeric_cols <- names(train)[sapply(train, is.numeric)]
predictor_cols <- setdiff(numeric_cols, "outcome")

rec <- recipe(outcome ~ ., data = train) |>
  step_normalize(all_of(predictor_cols))
```

**Correct approach**:
```r
# Use tidyselect helpers
rec <- recipe(outcome ~ ., data = train) |>
  step_normalize(all_numeric_predictors())
```

**Available selectors by role**:
- `has_role()`, `all_predictors()`, `all_outcomes()`

**Available selectors by type**:
- `has_type()`, `all_numeric()`, `all_integer()`, `all_double()`
- `all_nominal()`, `all_ordered()`, `all_unordered()`, `all_factor()`, `all_string()`
- `all_date()`, `all_datetime()`

**Combined selectors**:
- `all_numeric_predictors()`, `all_nominal_predictors()`

**References**:
- https://recipes.tidymodels.org/articles/Selecting_Variables.html
- https://recipes.tidymodels.org/reference/selections.html

### Misunderstanding Roles and New Data Requirements

**Problem**: Custom roles are required at `bake()` time by default. When using `step_rm()` to remove columns with custom roles, new data will fail if it doesn't have those columns.

**Scenario**: You have an ID column that you want to use for tracking but remove before modeling:

```r
# This will FAIL when baking new data that lacks 'id_column'
rec <- recipe(outcome ~ ., data = train) |>
  update_role(id_column, new_role = "id") |>
  step_rm(has_role("id"))

prepped <- prep(rec)
bake(prepped, new_data = new_data)  # Error: id_column not found
```

**Solution**: Use `update_role_requirements()` to make the role optional at bake time:

```r
rec <- recipe(outcome ~ ., data = train) |>
  update_role(id_column, new_role = "id") |>
  update_role_requirements("id", bake = FALSE) |>
  step_rm(has_role("id"))
```

**Reference**: https://recipes.tidymodels.org/reference/update_role_requirements.html

---

## workflows and workflowsets Problems

### Using Bare Lists Instead of workflow Objects

**Problem**: Creating ad-hoc lists to store model/recipe combinations instead of using `workflow()` objects.

**Wrong approach**:
```r
# Ad-hoc list structure
my_pipeline <- list(
  recipe = my_recipe,

  model = my_model
)
```

**Correct approach**:
```r
wflow <- workflow() |>
  add_recipe(my_recipe) |>
  add_model(my_model)
```

**Why workflows are better**:
- Consistent interface for fitting and prediction
- Proper handling of preprocessing during prediction
- Integration with tune, workflowsets, and other tidymodels packages

### workflowsets With Different Outcomes

**Problem**: Attempting to create a `workflow_set` where workflows predict different outcome variables.

**Constraint**: All workflows in a `workflow_set` must have the same outcome.

**Wrong approach**:
```r
# These recipes have different outcomes
rec_price <- recipe(price ~ ., data = train)
rec_quality <- recipe(quality ~ ., data = train)

# This will cause problems
workflow_set(
  preproc = list(price_rec = rec_price, quality_rec = rec_quality),
  models = list(lm = linear_reg())
)
```

**Correct approach**: Create separate workflow sets for different outcomes:

```r
price_set <- workflow_set(
  preproc = list(basic = rec_price),
  models = list(lm = linear_reg(), rf = rand_forest())
)

quality_set <- workflow_set(
  preproc = list(basic = rec_quality),
  models = list(lm = linear_reg(), rf = rand_forest())
)
```

---

## stacks Package Problems

### Missing Required Control Flags

**Problem**: Candidate models cannot be added to a stack because they were fit without the required metadata.

**Required flags**:
- `save_pred = TRUE` - Meta-model trains on out-of-sample predictions
- `save_workflow = TRUE` - `fit_members()` needs model specifications

**Wrong approach**:
```r
# Default control doesn't save what stacks needs
results <- tune_grid(wflow, resamples, grid = 10)
stack <- stacks() |>
  add_candidates(results)  # Will fail or produce incomplete stack
```

**Correct approach**:
```r
# Use stacks-specific control functions
ctrl <- control_stack_grid()  # or control_stack_resamples()

results <- tune_grid(wflow, resamples, grid = 10, control = ctrl)
stack <- stacks() |>
  add_candidates(results)  # Works correctly
```

---

## Data Leakage Problems

### Preprocessing Before Splitting

**Problem**: Applying preprocessing (normalization, imputation, etc.) to the entire dataset before splitting into train/test sets.

**Why this is bad**: Information from the test set "leaks" into the training process, leading to overly optimistic performance estimates.

**Wrong approach**:
```r
# Normalize entire dataset first
data$x <- scale(data$x)

# Then split - test set statistics influenced training
split <- initial_split(data)
```

**Correct approach**:
```r
# Split first
split <- initial_split(data)
train <- training(split)

# Preprocessing parameters estimated ONLY from training data
rec <- recipe(y ~ ., data = train) |>
  step_normalize(all_numeric_predictors())

# prep() uses only training data
prepped <- prep(rec, training = train)
```

### Using Test Set During Model Development

**Problem**: Repeatedly evaluating models on the test set during development, then reporting test set performance as final results.

**Correct approach**: Reserve test set for final evaluation only. Use validation sets or cross-validation during development:

```r
# For larger datasets: validation set approach
split <- initial_validation_split(data, prop = c(0.6, 0.2))
train <- training(split)
val <- validation(split)
test <- testing(split)

# For smaller datasets: cross-validation approach
split <- initial_split(data, prop = 0.8)
train <- training(split)
test <- testing(split)
folds <- vfold_cv(train, v = 10)

# Develop models using folds, THEN evaluate final model on test
```
