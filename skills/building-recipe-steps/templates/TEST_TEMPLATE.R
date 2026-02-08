# Test template for custom recipe steps.
# Replace STEPNAME with the actual step name (e.g., winsorize, lag, relocate).

test_that("step_STEPNAME works with all_predictors()", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_STEPNAME(all_predictors())

  rec_prepped <- prep(rec)
  rec_baked <- bake(rec_prepped, new_data = NULL)

  expect_s3_class(rec_prepped, "recipe")
  expect_true(tibble::is_tibble(rec_baked))
  expect_equal(nrow(rec_baked), nrow(mtcars))
})

test_that("step_STEPNAME tidy method works", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_STEPNAME(all_predictors())

  # Untrained
  tidied_untrained <- tidy(rec, number = 1)
  expect_s3_class(tidied_untrained, "tbl_df")
  expect_true("terms" %in% names(tidied_untrained))
  expect_true("id" %in% names(tidied_untrained))

  # Trained
  rec_prepped <- prep(rec)
  tidied_trained <- tidy(rec_prepped, number = 1)
  expect_s3_class(tidied_trained, "tbl_df")
  expect_true(all(tidied_trained$terms %in% names(mtcars)))
})

test_that("step_STEPNAME handles new data", {
  train <- mtcars[1:20, ]
  test <- mtcars[21:32, ]

  rec <- recipe(mpg ~ ., data = train) |>
    step_STEPNAME(all_numeric_predictors()) |>
    prep()

  result <- bake(rec, new_data = test)
  expect_equal(nrow(result), nrow(test))
})

test_that("step_STEPNAME errors on missing columns in new data", {
  train <- mtcars[1:20, ]
  test <- mtcars[21:32, ]

  rec <- recipe(mpg ~ ., data = train) |>
    step_STEPNAME(disp) |>
    prep()

  test_missing <- test[, setdiff(names(test), "disp")]
  expect_error(bake(rec, new_data = test_missing))
})

test_that("step_STEPNAME prints correctly", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_STEPNAME(all_predictors())

  expect_output(print(rec))

  rec_prepped <- prep(rec)
  expect_output(print(rec_prepped))
})

test_that("step_STEPNAME reports required packages", {
  rec <- recipe(mpg ~ ., data = mtcars) |>
    step_STEPNAME(all_predictors()) |>
    prep()

  pkgs <- required_pkgs(rec)
  expect_type(pkgs, "character")
})
