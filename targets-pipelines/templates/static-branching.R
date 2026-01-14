# Static Branching Template
#
# This template shows common patterns for static branching with tar_map()
# and tar_combine(). Copy and adapt for your pipeline.

# =============================================================================
# Pattern 1: Simple static branching over methods
# =============================================================================

# Define variants as a tibble with symbols for callable functions
values_methods <- tibble::tibble(
  method = rlang::syms(c("method_glm", "method_rf", "method_xgb")),
  method_name = c("glm", "rf", "xgb")
)

# Create targets for each method
method_targets <- tarchetypes::tar_map(
  values = values_methods,
  names = "method_name",
  targets::tar_target(result, method(training_data)),
  targets::tar_target(predictions, predict(result, test_data))
)

# =============================================================================
# Pattern 2: Static branching with aggregation
# =============================================================================

# Use unlist = FALSE when you need tar_combine()
mapped_with_combine <- tarchetypes::tar_map(
  unlist = FALSE,
  values = values_methods,
  names = "method_name",
  targets::tar_target(metrics, compute_metrics(method(data)))
)

# Combine results from all methods
combined_metrics <- tarchetypes::tar_combine(
  all_metrics,
  mapped_with_combine[["metrics"]],
  command = dplyr::bind_rows(!!!.x, .id = "method")
)

# =============================================================================
# Pattern 3: All combinations with expand_grid
# =============================================================================

# Create grid of all parameter combinations
# Note: Apply syms() AFTER expand_grid, not inside
params_grid <- tidyr::expand_grid(
  method_name = c("glm", "rf"),
  dataset = c("train", "validation", "test"),
  threshold = c(0.1, 0.5, 0.9)
)

# Add function symbols
params_grid$method <- rlang::syms(paste0("method_", params_grid$method_name))

# Map over all combinations
grid_targets <- tarchetypes::tar_map(
  values = params_grid,
  names = c("method_name", "dataset"),
  targets::tar_target(
    result,
    method(get_data(dataset), threshold = threshold)
  )
)

# =============================================================================
# Pattern 4: tar_eval for custom substitution
# =============================================================================

# When tar_map isn't flexible enough, use tar_eval
custom_targets <- tarchetypes::tar_eval(
  targets::tar_target(target_symbol, load_data(string_path)),
  values = list(
    target_symbol = rlang::syms(c("data_a", "data_b", "data_c")),
    string_path = c("data/a.csv", "data/b.csv", "data/c.csv")
  )
)

# =============================================================================
# Complete pipeline example
# =============================================================================

# Combine all patterns into a pipeline list
pipeline <- list(
  # Data loading
  targets::tar_target(training_data, load_training_data()),
  targets::tar_target(test_data, load_test_data()),

  # Static branching over methods
  method_targets,

  # Aggregation (if using Pattern 2)
  # combined_metrics,

 # Final summary
  targets::tar_target(
    final_report,
    generate_report(result_glm, result_rf, result_xgb)
  )
)
