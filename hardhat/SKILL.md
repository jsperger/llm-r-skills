---
name: hardhat-modeling-packages
description: >
  Use when creating an R modeling package that needs standardized preprocessing
  for formula, data frame, matrix, and recipe interfaces. Covers: mold() for
  training data preprocessing, forge() for prediction data validation,
  blueprints, model constructors, spruce functions for output formatting.
dependencies: R>=4.3, hardhat>=1.4.2
---

# Creating Modeling Packages with hardhat

The hardhat package provides infrastructure for building modeling packages with consistent interfaces. It standardizes preprocessing via `mold()` (training) and `forge()` (prediction), handling formula, XY, and recipe inputs uniformly.

## Quick Reference

| Task | Function |
|------|----------|
| Preprocess training data | `mold(x, y)` or `mold(formula, data)` |
| Preprocess prediction data | `forge(new_data, blueprint)` |
| Create model object | `new_model(..., blueprint, class)` |
| XY blueprint | `default_xy_blueprint(intercept = TRUE)` |
| Formula blueprint | `default_formula_blueprint(intercept = TRUE)` |
| Recipe blueprint | `default_recipe_blueprint(intercept = TRUE)` |
| Format numeric predictions | `spruce_numeric(pred)` |
| Format class predictions | `spruce_class(pred)` |
| Format probability predictions | `spruce_prob(pred)` |
| Validate univariate outcome | `validate_outcomes_are_univariate(outcomes)` |
| Validate prediction size | `validate_prediction_size(pred, new_data)` |

## Package Architecture

### Stage 1: Model Fitting

```
User → simple_lm() methods → bridge → implementation → constructor
         (formula/xy/recipe)    ↓           ↓              ↓
                            mold()    lm.fit()      new_model()
```

### Stage 2: Model Prediction

```
User → predict.simple_lm() → bridge → implementation
              ↓                ↓            ↓
          forge()          switch()   predict_*_numeric()
```

## Model Constructor

Create objects of your model class. Name: `new_<model_class>()`.

```r
new_simple_lm <- function(coefs, coef_names, blueprint) {
  if (!is.numeric(coefs)) {
    stop("`coefs` should be a numeric vector.", call. = FALSE)
  }
  if (!is.character(coef_names)) {
    stop("`coef_names` should be a character vector.", call. = FALSE)
  }

  new_model(
    coefs = coefs,
    coef_names = coef_names,
    blueprint = blueprint,
    class = "simple_lm"
  )
}
```

## Implementation Function

Core algorithm. Name: `<model_class>_impl()`. Returns named list of model elements.

```r
simple_lm_impl <- function(predictors, outcomes) {
  lm_fit <- lm.fit(predictors, outcomes)
  coefs <- lm_fit$coefficients

  list(
    coefs = unname(coefs),
    coef_names = names(coefs)
  )
}
```

## Bridge Function

Connects user-facing methods to implementation. Converts `mold()` output to implementation format.

```r
simple_lm_bridge <- function(processed) {
  validate_outcomes_are_univariate(processed$outcomes)

  predictors <- as.matrix(processed$predictors)
  outcomes <- processed$outcomes[[1]]

  fit <- simple_lm_impl(predictors, outcomes)

  new_simple_lm(
    coefs = fit$coefs,
    coef_names = fit$coef_names,
    blueprint = processed$blueprint
  )
}
```

## User-Facing Fitting Function

Generic with methods for each interface. Each method calls `mold()` then the bridge.

```r
simple_lm <- function(x, ...) {
 UseMethod("simple_lm")
}

simple_lm.default <- function(x, ...) {
  stop("`simple_lm()` is not defined for a '", class(x)[1], "'.", call. = FALSE)
}

simple_lm.data.frame <- function(x, y, intercept = TRUE, ...) {
  blueprint <- default_xy_blueprint(intercept = intercept)
  processed <- mold(x, y, blueprint = blueprint)
  simple_lm_bridge(processed)
}

simple_lm.matrix <- function(x, y, intercept = TRUE, ...) {
  blueprint <- default_xy_blueprint(intercept = intercept)
  processed <- mold(x, y, blueprint = blueprint)
  simple_lm_bridge(processed)
}

simple_lm.formula <- function(formula, data, intercept = TRUE, ...) {
  blueprint <- default_formula_blueprint(intercept = intercept)
  processed <- mold(formula, data, blueprint = blueprint)
  simple_lm_bridge(processed)
}

simple_lm.recipe <- function(x, data, intercept = TRUE, ...) {
  blueprint <- default_recipe_blueprint(intercept = intercept)
  processed <- mold(x, data, blueprint = blueprint)
  simple_lm_bridge(processed)
}
```

## Prediction Implementation

One function per prediction type. Use `spruce_*()` for standardized output.

```r
predict_simple_lm_numeric <- function(object, predictors) {
  coefs <- object$coefs
  pred <- as.vector(predictors %*% coefs)
  spruce_numeric(pred)  # Returns tibble with .pred column
}
```

## Prediction Bridge

Converts `forge()` output and switches on type.

```r
predict_simple_lm_bridge <- function(type, object, predictors) {
  type <- rlang::arg_match(type, "numeric")
  predictors <- as.matrix(predictors)

  switch(
    type,
    numeric = predict_simple_lm_numeric(object, predictors)
  )
}
```

## User-Facing Predict Method

Call `forge()` with blueprint, then bridge, then validate.

```r
predict.simple_lm <- function(object, new_data, type = "numeric", ...) {
  processed <- forge(new_data, object$blueprint)
  out <- predict_simple_lm_bridge(type, object, processed$predictors)
  validate_prediction_size(out, new_data)
  out
}
```

## mold() Details

Returns: `predictors` (tibble), `outcomes` (tibble), `extras`, `blueprint`.

### Blueprint Options

| Blueprint | Key Options |
|-----------|-------------|
| `default_xy_blueprint()` | `intercept` |
| `default_formula_blueprint()` | `intercept`, `indicators` ("traditional", "none", "one_hot") |
| `default_recipe_blueprint()` | `intercept` |

### Formula Special Behaviors

- No intercept by default (unlike base R)
- `indicators = "none"` keeps factors unexpanded
- Multivariate outcomes: `y1 + y2 ~ x1 + x2` (not `cbind()`)

## forge() Validation

Automatically validates new data matches training data:
- Column names must match
- Column types must be compatible
- Factor levels must be subset of training levels
- Lossy conversions emit warnings (novel levels → NA)

```r
# Missing column → error
# Wrong type (double for factor) → error
# Character for factor → silent conversion
# Novel factor level → warning + NA
```

## Spruce Functions

Standardize prediction output to tidymodels conventions:

| Function | Output Column |
|----------|---------------|
| `spruce_numeric(pred)` | `.pred` |
| `spruce_class(pred)` | `.pred_class` |
| `spruce_prob(pred_matrix)` | `.pred_{class_name}` |

## Validation Functions

| Function | Checks |
|----------|--------|
| `validate_outcomes_are_univariate()` | Single outcome column |
| `validate_prediction_size()` | Output rows == input rows |
| `validate_outcomes_are_numeric()` | Numeric outcomes |
| `validate_predictors_are_numeric()` | Numeric predictors |

## See Also

- **designing-tidy-r-functions**: Function API design
- **r-metaprogramming**: Expression manipulation (if customizing blueprints)
- **testing-r-packages**: Testing patterns

## Vignettes

Access detailed documentation via R:

```r
# Open vignette in browser
RShowDoc("mold", package = "hardhat")    # Molding data for modeling
RShowDoc("forge", package = "hardhat")   # Forging data for predictions
RShowDoc("package", package = "hardhat") # Creating modeling packages

# Or browse all vignettes
browseVignettes("hardhat")
```

## External Resources

- [tidymodels implementation principles](https://tidymodels.github.io/model-implementation-principles/)
- [hardhat documentation](https://hardhat.tidymodels.org/)
