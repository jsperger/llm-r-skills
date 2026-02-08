# Example feature engineering with `recipes`

```r
# Feature Engineering Template for 'recipes'
library(recipes)
library(rsample)
library(modeldata)

# 0. Setup Data (Example)
data("credit_data")
set.seed(55)
split <- rsample::initial_split(credit_data, prop = 0.75)
train_data <- rsample::training(split)
test_data  <- rsample::testing(split)

# 1. DEFINE the Recipe
# No calculations happen here — this builds the preprocessing plan.
rec_spec <- recipes::recipe(Status ~ ., data = train_data) |>
  # Impute missing values (using training distribution)
  recipes::step_impute_median(all_numeric_predictors()) |>
  recipes::step_impute_mode(all_nominal_predictors()) |>
  # Handle novel levels in test data
  recipes::step_novel(all_nominal_predictors()) |>
  # Convert categories to dummy variables
  recipes::step_dummy(all_nominal_predictors()) |>
  # Remove zero-variance variables
  recipes::step_nzv(all_predictors()) |>
  # Normalize (Center and Scale)
  recipes::step_normalize(all_predictors())

# 2. PREPARE (Estimate)
# Calculations happen here using ONLY training data
rec_prepped <- recipes::prep(rec_spec, training = train_data)

# 3. BAKE (Execute)
# Apply the calculations to datasets
# bake(new_data = NULL) is a shortcut for baking the training data used in prep()
train_processed <- recipes::bake(rec_prepped, new_data = NULL)
test_processed  <- recipes::bake(rec_prepped, new_data = test_data)

# Verification
print(rec_prepped)
head(train_processed)
```
