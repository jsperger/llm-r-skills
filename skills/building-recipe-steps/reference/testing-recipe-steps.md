# Testing Custom Recipe Steps

Reference for writing testthat tests for custom `step_*()` functions. Assumes testthat 3e is already configured.

## Test File Organization

Place tests in `tests/testthat/test-step_{name}.R`, mirroring the source file `R/step_{name}.R`.

## What to Test

Every custom recipe step needs tests covering these areas:

### 1. Basic Prep/Bake Round-Trip

Verify the step can be added to a recipe, prepped, and baked without error, and that the output is a tibble with the correct dimensions.

```r
test_that("step_{name} works with all_predictors()", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_predictors())

  rec_prepped <- prep(rec)
  rec_baked <- bake(rec_prepped, new_data = NULL)

  expect_s3_class(rec_prepped, "recipe")
  expect_true(tibble::is_tibble(rec_baked))
  expect_equal(nrow(rec_baked), nrow(mtcars))
})
```

### 2. Transformation Correctness

Verify the step produces the expected transformation. Compare against a known manual calculation.

```r
test_that("step_{name} produces correct values", {
  train <- data.frame(x = c(1, 2, 3, 4, 5), y = c(10, 20, 30, 40, 50))

  rec <- recipe(~ ., data = train) |>
    step_{name}(all_predictors()) |>
    prep()

  result <- bake(rec, new_data = NULL)

  # Compare against manually computed expected values
  expected_x <- c(...)  # fill in expected transformation
  expect_equal(result$x, expected_x)
})
```

### 3. New Data Handling

Verify that baking with new data applies the parameters estimated from training data, not re-estimated from the new data.

```r
test_that("step_{name} applies training parameters to new data", {
  train <- mtcars[1:20, ]
  test  <- mtcars[21:32, ]

  rec <- recipe(mpg ~ ., data = train) |>
    step_{name}(all_numeric_predictors()) |>
    prep()

  result <- bake(rec, new_data = test)
  expect_equal(nrow(result), nrow(test))
  expect_equal(ncol(result), ncol(test))
})
```

### 4. Missing Column Detection

Verify that `check_new_data()` catches missing columns at bake time.

```r
test_that("step_{name} errors on missing columns in new data", {
  train <- mtcars[1:20, ]
  test  <- mtcars[21:32, ]

  rec <- recipe(mpg ~ ., data = train) |>
    step_{name}(disp) |>
    prep()

  test_missing <- test[, setdiff(names(test), "disp")]
  expect_error(bake(rec, new_data = test_missing))
})
```

### 5. Tidy Method

Verify the tidy method returns a tibble with `terms` and `id` columns, in both trained and untrained states.

```r
test_that("step_{name} tidy method works", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_predictors())

  # Untrained
  tidied <- tidy(rec, number = 1)
  expect_s3_class(tidied, "tbl_df")
  expect_true("terms" %in% names(tidied))
  expect_true("id" %in% names(tidied))

  # Trained
  rec_prepped <- prep(rec)
  tidied_trained <- tidy(rec_prepped, number = 1)
  expect_s3_class(tidied_trained, "tbl_df")
  expect_true(all(tidied_trained$terms %in% names(mtcars)))
})
```

### 6. Print Method

Verify the step prints without error in both states.

```r
test_that("step_{name} prints correctly", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_predictors())

  expect_output(print(rec))

  rec_prepped <- prep(rec)
  expect_output(print(rec_prepped))
})
```

### 7. Required Packages

Verify the step declares its package dependencies.

```r
test_that("step_{name} reports required packages", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_predictors()) |>
    prep()

  pkgs <- required_pkgs(rec)
  expect_type(pkgs, "character")
  expect_true("mypackage" %in% pkgs)
})
```

### 8. Selector Compatibility

Verify the step works with various tidyselect helpers.

```r
test_that("step_{name} works with different selectors", {
  rec_numeric <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_numeric_predictors()) |>
    prep()
  expect_no_error(bake(rec_numeric, new_data = NULL))

  rec_named <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(disp, hp, wt) |>
    prep()
  expect_no_error(bake(rec_named, new_data = NULL))
})
```

### 9. Workflow Integration

Verify the step works inside a tidymodels workflow.

```r
test_that("step_{name} works inside a workflow", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_numeric_predictors())

  spec <- parsnip::linear_reg() |>
    parsnip::set_engine("lm")

  wflow <- workflows::workflow() |>
    workflows::add_recipe(rec) |>
    workflows::add_model(spec)

  fitted <- fit(wflow, data = mtcars)
  preds <- predict(fitted, new_data = mtcars[1:5, ])

  expect_s3_class(preds, "tbl_df")
  expect_equal(nrow(preds), 5)
})
```

### 10. Edge Cases

Test boundary conditions relevant to the step.

```r
test_that("step_{name} handles single column", {
  rec <- recipe(mpg ~ disp, data = mtcars) |>
    step_{name}(all_predictors()) |>
    prep()

  result <- bake(rec, new_data = NULL)
  expect_equal(ncol(result), 2)  # outcome + 1 predictor
})

test_that("step_{name} handles NA values appropriately", {
  train <- mtcars[1:20, ]
  train$disp[1:3] <- NA

  rec <- recipe(mpg ~ ., data = train) |>
    step_{name}(disp)

  # Behavior depends on step design:
  # Either expect_error(prep(rec)) or verify NA handling
})
```

## testthat Expectations Quick Reference

| Expectation | Purpose |
|---|---|
| `expect_equal(x, y)` | Numeric equality with tolerance |
| `expect_identical(x, y)` | Exact match |
| `expect_true(x)` / `expect_false(x)` | Logical assertions |
| `expect_s3_class(x, "class")` | S3 class check |
| `expect_type(x, "type")` | Base type check |
| `expect_length(x, n)` | Length check |
| `expect_error(expr)` | Expect an error |
| `expect_error(expr, class = "cls")` | Expect error of specific class |
| `expect_no_error(expr)` | No error |
| `expect_warning(expr)` | Expect a warning |
| `expect_no_warning(expr)` | No warning |
| `expect_output(expr)` | Expect printed output |
| `expect_match(string, "pattern")` | Regex match |
| `expect_named(x, c("a", "b"))` | Name check |
| `expect_snapshot(expr)` | Snapshot test |
| `expect_setequal(x, y)` | Same elements, any order |
| `expect_contains(x, y)` | x contains all elements of y |

## Test Design Principles

- **Self-sufficient**: Each `test_that()` block contains all setup needed. Do not rely on objects created in other tests.
- **Self-contained**: Clean up side effects with `withr::local_*()` functions. Tests must not leave state behind.
- **Repetition is OK**: Repeat data setup across tests rather than factoring it out. Test clarity matters more than DRY.
- **Test behavior, not implementation**: Focus on what the step does (correct output) not how it does it (internal structure).
- **Use `bake(new_data = NULL)` for training data**: This is the idiomatic way to retrieve preprocessed training data from a prepped recipe.
- **Never match on message strings**: Do not pass regex or string arguments to `expect_error()`, `expect_warning()`, or `expect_message()` to match message text. Use `class =` to match error classes when available. To verify the exact wording of user-facing messages, use `expect_snapshot()` instead. String matching makes tests brittle to rewording.

## Testing User-Facing Messages with Snapshots

**Never test message strings directly.** Use snapshots for verifying error messages, warning text, and printed output.

```r
# WRONG — brittle to rewording
test_that("step errors on bad type", {
  expect_error(
    recipe(...) |> step_{name}(all_nominal_predictors()) |> prep(),
    "must be numeric"
  )
})

# CORRECT — use class for programmatic conditions
test_that("step errors on bad type", {
  expect_error(
    recipe(...) |> step_{name}(all_nominal_predictors()) |> prep(),
    class = "vctrs_error_incompatible_type"
  )
})

# CORRECT — use snapshot for exact message wording
test_that("step_{name} has informative error for wrong types", {
  expect_snapshot(
    error = TRUE,
    recipe(mpg ~ ., data = mtcars) |>
      step_{name}(all_nominal_predictors()) |>
      prep()
  )
})
```

### Snapshot Patterns for Recipe Steps

```r
# Error message snapshot
test_that("step_{name} error on wrong type is informative", {
  expect_snapshot(
    error = TRUE,
    recipe(mpg ~ ., data = mtcars) |>
      step_{name}(all_nominal_predictors()) |>
      prep()
  )
})

# Warning snapshot
test_that("step_{name} warns about edge case", {
  expect_snapshot(
    recipe(mpg ~ ., data = mtcars) |>
      step_{name}(all_predictors(), option = "unusual") |>
      prep()
  )
})

# Print output snapshot
test_that("step_{name} print output is stable", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_{name}(all_predictors()) |>
    prep()

  expect_snapshot(print(rec))
})
```

Snapshots are stored in `tests/testthat/_snaps/`. Review with `testthat::snapshot_review()` and accept with `testthat::snapshot_accept()`.
