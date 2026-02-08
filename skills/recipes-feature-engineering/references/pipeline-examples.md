# Recipes in Tidymodels Pipelines

Complete examples showing recipes integrated with workflows, tuning, and model comparison.

## Single Model with Tuning

```r
library(tidymodels)

# Data splitting
set.seed(123)
data_split <- initial_split(ames, prop = 0.8, strata = Sale_Price)
train_data <- training(data_split)
test_data  <- testing(data_split)
folds <- vfold_cv(train_data, v = 10, strata = Sale_Price)

# Recipe
ames_rec <- recipe(Sale_Price ~ ., data = train_data) |>
  step_log(Sale_Price, base = 10) |>
  step_other(all_nominal_predictors(), threshold = 0.05) |>
  step_novel(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors())

# Model with tunable hyperparameters
rf_spec <- rand_forest(mtry = tune(), min_n = tune(), trees = 1000) |>
  set_engine("ranger") |>
  set_mode("regression")

# Workflow
rf_wflow <- workflow() |>
  add_recipe(ames_rec) |>
  add_model(rf_spec)

# Tune
rf_results <- tune_grid(
  rf_wflow,
  resamples = folds,
  grid = 20,
  metrics = metric_set(rmse, rsq)
)

# Finalize and evaluate on test set
best_params <- select_best(rf_results, metric = "rmse")
final_wflow <- finalize_workflow(rf_wflow, best_params)
final_fit <- last_fit(final_wflow, split = data_split)
collect_metrics(final_fit)
```

## Comparing Multiple Recipes with workflowsets

Different preprocessing strategies can be compared systematically:

```r
library(tidymodels)

set.seed(42)
split <- initial_split(ames, prop = 0.8, strata = Sale_Price)
train <- training(split)
folds <- vfold_cv(train, v = 5, strata = Sale_Price)

# Recipe 1: Minimal preprocessing
rec_basic <- recipe(Sale_Price ~ ., data = train) |>
  step_log(Sale_Price, base = 10) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors())

# Recipe 2: Normalized with interaction terms
rec_normalized <- recipe(Sale_Price ~ ., data = train) |>
  step_log(Sale_Price, base = 10) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_interact(terms = ~ Gr_Liv_Area:starts_with("Bldg_Type"))

# Recipe 3: PCA dimensionality reduction
rec_pca <- recipe(Sale_Price ~ ., data = train) |>
  step_log(Sale_Price, base = 10) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_pca(all_numeric_predictors(), threshold = 0.95)

# Models
lm_spec <- linear_reg() |> set_engine("lm")
rf_spec <- rand_forest(trees = 500) |> set_engine("ranger") |> set_mode("regression")

# Create workflow set: cross all recipes with all models
wflow_set <- workflow_set(
  preproc = list(basic = rec_basic, normalized = rec_normalized, pca = rec_pca),
  models = list(lm = lm_spec, rf = rf_spec)
)

# Evaluate all combinations
results <- workflow_map(
  wflow_set,
  resamples = folds,
  metrics = metric_set(rmse, rsq),
  verbose = TRUE
)

# Compare
autoplot(results)
rank_results(results, rank_metric = "rmse")
```

## Recipes for Model Stacking

When building ensembles with stacks, candidate models must save predictions and workflows:

```r
library(tidymodels)
library(stacks)

set.seed(1)
split <- initial_split(ames, prop = 0.8, strata = Sale_Price)
train <- training(split)
folds <- vfold_cv(train, v = 5, strata = Sale_Price)

# Shared recipe
base_rec <- recipe(Sale_Price ~ ., data = train) |>
  step_log(Sale_Price, base = 10) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors())

# Candidate 1: Elastic net
enet_spec <- linear_reg(penalty = tune(), mixture = tune()) |>
  set_engine("glmnet")

enet_wflow <- workflow() |>
  add_recipe(base_rec) |>
  add_model(enet_spec)

# Use stacks-specific control
ctrl <- control_stack_grid()

enet_results <- tune_grid(
  enet_wflow,
  resamples = folds,
  grid = 10,
  control = ctrl
)

# Candidate 2: Random forest
rf_spec <- rand_forest(mtry = tune(), min_n = tune(), trees = 500) |>
  set_engine("ranger") |>
  set_mode("regression")

rf_wflow <- workflow() |>
  add_recipe(base_rec) |>
  add_model(rf_spec)

rf_results <- tune_grid(
  rf_wflow,
  resamples = folds,
  grid = 10,
  control = ctrl
)

# Build stack
model_stack <- stacks() |>
  add_candidates(enet_results) |>
  add_candidates(rf_results) |>
  blend_predictions() |>
  fit_members()

# Predict
stack_preds <- predict(model_stack, new_data = testing(split))
```

## Recipe with Custom Role and Validation Set

```r
library(tidymodels)

set.seed(99)
split <- initial_validation_split(ames, prop = c(0.6, 0.2), strata = Sale_Price)
train <- training(split)
val_set <- validation_set(split)

rec <- recipe(Sale_Price ~ ., data = train) |>
  update_role(Order, PID, new_role = "id") |>
  update_role_requirements("id", bake = FALSE) |>
  step_log(Sale_Price, base = 10) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_novel(all_nominal_predictors()) |>
  step_other(all_nominal_predictors(), threshold = 0.02) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors())

spec <- boost_tree(trees = tune(), learn_rate = tune()) |>
  set_engine("xgboost") |>
  set_mode("regression")

wflow <- workflow() |>
  add_recipe(rec) |>
  add_model(spec)

# Tune using validation set (faster than cross-validation)
tuned <- tune_grid(
  wflow,
  resamples = val_set,
  grid = 20,
  metrics = metric_set(rmse, rsq)
)

best <- select_best(tuned, metric = "rmse")
final_fit <- last_fit(finalize_workflow(wflow, best), split = split)
collect_metrics(final_fit)
```
