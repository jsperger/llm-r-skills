# Step template for custom recipe steps.
# Placeholders to replace:
#   STEPNAME              - step identifier (e.g., winsorize, lag)
#   ACTIONDESC            - human-readable title (e.g., Winsorize numeric variables)
#   ACTIONDESC_LOWER      - lowercase for roxygen (e.g., winsorize numeric variables)
#   PKGNAME               - package this step belongs to

#' ACTIONDESC
#'
#' `step_STEPNAME()` creates a specification of a recipe step that
#' will ACTIONDESC_LOWER.
#'
#' @param recipe A recipe object. The step will be added to the sequence of
#'   operations for this recipe.
#' @param ... One or more selector functions to choose variables for this step.
#'   See [recipes::selections()] for more details.
#' @param role Not used by this step since no new variables are created.
#' @param trained A logical to indicate if the quantities for preprocessing
#'   have been estimated.
#' @param columns A character string of the selected variable names. This field
#'   is a placeholder and will be populated once [recipes::prep()] is used.
#' @param skip A logical. Should the step be skipped when the recipe is baked
#'   by [recipes::bake()]? While all operations are baked when [recipes::prep()]
#'   is run, some operations may not be applicable to new data (e.g.,
#'   processing the outcome variable(s)). Care should be taken when using
#'   `skip = TRUE` as it may affect the computations for subsequent operations.
#' @param id A character string that is unique to this step to identify it.
#'
#' @return An updated version of `recipe` with the new step added to the
#'   sequence of any existing operations.
#'
#' @export
#' @examples
#' library(recipes)
#' rec <- recipe(mpg ~ ., data = mtcars) |>
#'   step_STEPNAME(all_numeric_predictors())
#' rec
step_STEPNAME <- function(
  recipe,
  ...,
  role = NA,
  trained = FALSE,
  columns = NULL,
  skip = FALSE,
  id = recipes::rand_id("STEPNAME")
) {
  recipes::add_step(
    recipe,
    step_STEPNAME_new(
      terms = enquos(...),
      role = role,
      trained = trained,
      columns = columns,
      skip = skip,
      id = id
    )
  )
}

# S3 Object Initialization (internal)
step_STEPNAME_new <- function(terms, role, trained, columns, skip, id) {
  recipes::step(
    subclass = "STEPNAME",
    terms = terms,
    role = role,
    trained = trained,
    columns = columns,
    skip = skip,
    id = id
  )
}

#' @export
prep.step_STEPNAME <- function(x, training, info = NULL, ...) {
  col_names <- recipes::recipes_eval_select(x$terms, training, info)

  # Check that selected columns are of the expected type
  recipes::check_type(training[, col_names], types = c("double", "integer"))

  ## ESTIMATE PARAMETERS HERE
  ## Example: means <- vapply(training[, col_names], mean, numeric(1), na.rm = TRUE)

  step_STEPNAME_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    columns = col_names,
    ## Store estimated parameters here, e.g.:
    ## means = means,
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_STEPNAME <- function(object, new_data, ...) {
  col_names <- object$columns
  recipes::check_new_data(col_names, object, new_data)

  ## APPLY TRANSFORMATION HERE
  ## Example:
  ## for (col in col_names) {
  ##   new_data[[col]] <- new_data[[col]] - object$means[[col]]
  ## }

  tibble::as_tibble(new_data)
}

#' @export
print.step_STEPNAME <- function(x, width = max(20, options()$width - 30), ...) {
  title <- "ACTIONDESC "
  recipes::print_step(x$columns, x$terms, x$trained, title, width)
  invisible(x)
}

#' @export
tidy.step_STEPNAME <- function(x, ...) {
  if (recipes::is_trained(x)) {
    res <- tibble::tibble(terms = x$columns)
  } else {
    res <- tibble::tibble(terms = recipes::sel2char(x$terms))
  }
  res$id <- x$id
  res
}

#' @export
required_pkgs.step_STEPNAME <- function(x, ...) {
  ## List packages required for this step (for parallel processing safety)
  c("PKGNAME")
}
