# Targetopia package development

## Overview 

## Quick Reference

| Task | Function/Pattern |
|------|------------------|
| Create target in factory | `tar_target_raw(name, command, ...)` |
| Test in temp directory | `targets::tar_test()` |
| Check pipeline structure | `tar_manifest()`, `tar_network()` |

## Documentation

### Writing examples

Keep `@examples` fast and use temporary files. Use `tar_dir()` for runnable examples:

```r
#' @examples
#' targets::tar_dir({
#'   targets::tar_script(target_factory(example, "data.csv"))
#'   targets::tar_make()
#' })
```

## Testing

### What to Test

1. **Results**: Run pipeline, check outputs
2. **Manifest**: Verify target count, commands, settings
3. **Dependencies**: Check graph edges between targets

### tar_test() Pattern
Runs a test_that() unit test inside a temporary directory to avoid writing to the user's file space

```r
targets::tar_test("factory creates correct targets", {
  # Runs in temp directory, resets options after
  targets <- target_factory(test, "data.csv")
  expect_length(targets, 3)
  expect_equal(targets[[1]]$settings$name, "test_file")
})
```

### Speed Tips

- Use `callr_function = NULL` in `tar_make()` for faster tests (but sensitive to test environment)
- Use `testthat::skip_on_cran()` for slow tests

## See Also

[utilities for package authors](references/targets_utilities.md)
