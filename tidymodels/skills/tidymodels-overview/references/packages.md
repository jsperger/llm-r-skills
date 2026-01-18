# Tidymodels Package Reference

Detailed documentation for each tidymodels package including object structures, key functions, and integration points.

## recipes

The `recipes` package defines preprocessing data and feature engineering steps.

### recipe Object Structure

- **var_info**: Tibble with information about variables in the original data (name, type, role)
- **term_info**: Tibble with information about terms used in the recipe (name, type, role, source)
- **steps**: List of step objects (e.g., `step_normalize`, `step_dummy`), each defining a transformation
- **template**: Tibble (often 0-row) capturing the names and types of data used to train the recipe (after `prep()`)
- **trained**: Logical flag, `FALSE` initially, becomes `TRUE` after `prep()` is called

### Creation and Use

1. Initialize with `recipe(formula, data)`
2. Add transformation steps sequentially (`step_normalize()`, `step_dummy()`, etc.)
3. This creates an **unprepped** recipe object
4. `prep()` estimates parameters from training data
5. `bake()` applies the prepped recipe to new data
6. `juice()` extracts the preprocessed training data (deprecated in favor of `bake(new_data = NULL)`)

### Variable Selection

Role-based selectors:
- `all_predictors()`, `all_outcomes()` - select by assigned role
- `has_role("custom_role")` - select by specific role

Type-based selectors:
- `all_numeric()`, `all_nominal()`, `all_factor()`, `all_string()`
- `all_integer()`, `all_double()`, `all_ordered()`, `all_unordered()`
- `all_date()`, `all_datetime()`

Combined selectors:
- `all_numeric_predictors()`, `all_nominal_predictors()` - type AND role

### Deep Knowledge

- [Selecting Variables](https://recipes.tidymodels.org/articles/Selecting_Variables.html)
- [Recipe Internals](https://recipes.tidymodels.org/articles/internals.html)
- [Selection Reference](https://recipes.tidymodels.org/reference/selections.html)

---

## parsnip

The `parsnip` package provides a consistent interface for specifying models via the `model_spec` S3 object.

### model_spec Object Structure

- **args**: Named list of primary model arguments (e.g., `penalty`, `mtry`), stored as quosures to be evaluated at fit time
- **engine**: Character string specifying the computational engine (e.g., `"lm"`, `"glmnet"`)
- **mode**: Character string for the modeling task (`"regression"`, `"classification"`)
- **method**: Internal list with engine-specific details for fitting and prediction ("translation layer")

### Creation Process

1. Instantiate a base model: `linear_reg()`, `rand_forest()`, etc.
2. Specify the computational engine: `set_engine("glmnet")`
3. Confirm the modeling mode: `set_mode("regression")`

### Key Model Functions

| Function | Model Type |
|----------|------------|
| `linear_reg()` | Linear regression |
| `logistic_reg()` | Logistic regression |
| `rand_forest()` | Random forest |
| `boost_tree()` | Gradient boosting |
| `decision_tree()` | Single decision tree |
| `svm_rbf()`, `svm_linear()`, `svm_poly()` | Support vector machines |
| `mlp()` | Neural network (multilayer perceptron) |
| `cubist_rules()` | Cubist rule-based model |

---

## hardhat

The `hardhat` package provides foundational tools for applying data transformations consistently using "blueprints." Often used internally by `workflows`.

### Blueprints

Instruction sets defining how data is processed:
- `formula_blueprint` - for formula-based preprocessing
- `recipe_blueprint` - for recipe-based preprocessing

Purpose: Store learned parameters from training data to ensure consistent application.

### recipe_blueprint Key Slots (after mold())

- **recipe**: The *prepped* `recipes::recipe` object
- **ptypes**: Prototypes (empty tibbles) of processed predictors and outcomes
- **intercept**: Logical flag indicating if an intercept is added post-recipe
- **allow_novel_levels**: Logical flag for handling new factor levels

### Core Process

1. **`mold()`**: Used on training data
   - Preps the preprocessor (e.g., a recipe)
   - Creates the blueprint
   - Processes the data
   - Outputs: processed predictors, outcomes, and the prepped blueprint

2. **`forge()`**: Used on new data
   - Applies stored transformations from the prepped blueprint
   - Ensures consistency between training and prediction

---

## workflows

The `workflows` package bundles preprocessing (recipes/formulas) and model specifications into a single `workflow` S3 object.

### workflow Object Structure

- **actions**: List defining operations
  - `preprocessor` holds the recipe/formula
  - `model` holds the `model_spec`
- **pre$mold** (after fit): Contains output of `hardhat::mold()`, including the prepped blueprint and processed data
- **fit$fit** (after fit): Holds the fitted `parsnip::model_fit` object
- **trained**: Logical flag, `FALSE` initially, set to `TRUE` after fitting

### Key Processes

- **`fit.workflow()`**: Orchestrates training
  1. Calls `hardhat::mold()` on training data
  2. Passes processed data to `parsnip::fit()`

- **`predict.workflow()`**: Ensures consistent prediction
  1. Retrieves prepped blueprint from fitted workflow
  2. Uses `hardhat::forge()` to process new data
  3. Calls `predict()` on the fitted model

---

## workflowsets

The `workflowsets` package creates, manages, and evaluates collections of multiple workflows.

### workflow_set Object Structure

A tibble where each row represents a unique workflow, using list-columns:

- **wflow_id**: Character string providing unique identifier
- **info**: List-column containing the unevaluated `workflow` object
- **option**: List-column for evaluation options (e.g., tuning grids)
- **result**: List-column populated with evaluation results (e.g., `tune_results` objects)

### Evaluation Process

`workflow_map()` applies an evaluation function to each workflow:
1. Iterates through each row
2. Extracts the workflow
3. Applies the specified function with its options
4. Stores output in the `result` column

### Important Constraint

**All workflows in a workflow_set must have the same outcome variable.** For different outcomes, create separate workflow sets.

---

## rsample

The `rsample` package provides standardized framework for creating and managing data splits.

### rset and rsplit Object Structure

- **rset**: Tibble representing a collection of resamples
- **rsplit**: S3 object representing a single split

rsplit stores:
- Reference to original data (not a copy)
- Integer indices for **analysis** (training) and **assessment** (testing/holdout) sets

### Memory Efficiency

rsplit objects do not copy the data; they store a reference to the original environment's data frame and specific integer pointers.

### Core Functions

- `initial_split()` - Single train/test partition
- `initial_validation_split()` - Train/validation/test partition
- `vfold_cv()` - V-fold cross-validation
- `bootstraps()` - Bootstrap resampling
- `training()`, `testing()` - Extract data from split
- `analysis()`, `assessment()` - Extract data from rsplit

---

## tune

The `tune` package provides tools for hyperparameter optimization.

### tune_results Object Structure

A subclass of `rset` that augments the resample tibble with evaluation data:

- **.metrics**: List-column of tibbles containing performance values for each parameter combination
- **.notes**: List-column of tibbles capturing warnings or errors during fit
- **.predictions**: List-column (optional) of out-of-sample predictions
- **parameters** (attribute): A `dials` parameter object defining the search space

### Tuning Algorithms

**Grid Search (`tune_grid()`)**: Evaluates pre-defined hyperparameter combinations
- Regular grids: Cartesian product of parameter levels
- Space-filling designs: Latin Hypercube for better coverage

**Bayesian Optimization (`tune_bayes()`)**: Uses Gaussian Process surrogate model with acquisition function (e.g., Expected Improvement)

### Key Functions

- `tune()` - Placeholder for tunable parameters
- `tune_grid()`, `tune_bayes()` - Tuning functions
- `select_best()`, `select_by_one_std_err()`, `select_by_pct_loss()` - Select best parameters
- `finalize_workflow()` - Apply selected parameters
- `last_fit()` - Final fit on training, evaluate on test

---

## yardstick

The `yardstick` package quantifies model performance with tidyverse-compliant output.

### Metric Tibble Structure

All functions return a tibble with exactly three columns:
- **.metric**: Name of the metric (e.g., `"rmse"`, `"roc_auc"`)
- **.estimator**: Type of estimator (e.g., `"standard"`, `"macro"`, `"macro_weighted"`)
- **.estimate**: Calculated numerical value

### metric_set

Bundle multiple metrics for consistent evaluation:

```r
metrics <- metric_set(rmse, rsq, mae)
metrics(data, truth = actual, estimate = predicted)
```

### Common Metrics

**Regression**: `rmse()`, `rsq()`, `mae()`, `mape()`, `huber_loss()`

**Classification**: `accuracy()`, `roc_auc()`, `pr_auc()`, `f_meas()`, `kap()`

**Multiclass**: Use `.estimator` argument (`"macro"`, `"micro"`, `"weighted"`)

---

## stacks

The `stacks` package builds model ensembles using stacking.

### Stacking Workflow

1. **`stacks()`**: Create empty `data_stack` object
2. **`add_candidates()`**: Add tuning/resampling results
3. **`blend_predictions()`**: Fit meta-model (LASSO) to determine weights
4. **`fit_members()`**: Train retained models on full training data
5. **`predict()`**: Generate ensemble predictions

### Critical Requirements

Candidate model results must contain specific metadata:

```r
# Use these control functions
ctrl <- control_stack_grid()    # for tune_grid()
ctrl <- control_stack_resamples()  # for fit_resamples()
```

These helpers set:
- `save_pred = TRUE` - Required because meta-model trains on out-of-sample predictions
- `save_workflow = TRUE` - Required so `fit_members()` knows model specifications

### Integration with workflowsets

Pass a trained `workflow_set` directly to `add_candidates()` to batch-add all successful workflows.
