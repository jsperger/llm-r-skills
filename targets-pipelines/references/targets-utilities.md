# `targets` utilities for package authors
## Metaprogramming
`tar_deparse_language()` is a wrapper around `tar_deparse_safe()` which leaves character vectors and NULL objects alone, which helps with subsequent user input validation.

`tar_deparse_safe()` is a wrapper around base::deparse() with a custom set of fast default settings and guardrails to ensure the output always has length 1.

`tar_tidy_eval()` applies tidy evaluation to a language object and returns another language object.

`tar_tidyselect_eval()` applies tidyselect selection with some special guardrails around NULL inputs.

## Conditions
Throw custom targets-specific error conditions

```R
targets::tar_print(...)

targets::tar_error(message, class)

targets::tar_warning(message, class)

targets::tar_message(message, class)
```


## Assertions
Use `targets` assertions to check the correctness of user inputs and generate custom error conditions as needed. 

```R
targets::tar_assert_chr(x, msg = NULL)

targets::tar_assert_dbl(x, msg = NULL)

targets::tar_assert_df(x, msg = NULL)

targets::tar_assert_equal_lengths(x, msg = NULL)

targets::tar_assert_envir(x, msg = NULL)

targets::tar_assert_expr(x, msg = NULL)

targets::tar_assert_flag(x, choices, msg = NULL)

targets::tar_assert_file(x)

targets::tar_assert_finite(x, msg = NULL)

targets::tar_assert_function(x, msg = NULL)

targets::tar_assert_function_arguments(x, args, msg = NULL)

targets::tar_assert_ge(x, threshold, msg = NULL)

targets::tar_assert_identical(x, y, msg = NULL)

targets::tar_assert_in(x, choices, msg = NULL)

targets::tar_assert_not_dirs(x, msg = NULL)

targets::tar_assert_not_dir(x, msg = NULL)

targets::tar_assert_not_in(x, choices, msg = NULL)

targets::tar_assert_inherits(x, class, msg = NULL)

targets::tar_assert_int(x, msg = NULL)

targets::tar_assert_internet(msg = NULL)

targets::tar_assert_lang(x, msg = NULL)

targets::tar_assert_le(x, threshold, msg = NULL)

targets::tar_assert_list(x, msg = NULL)

targets::tar_assert_lgl(x, msg = NULL)

targets::tar_assert_name(x)

targets::tar_assert_named(x, msg = NULL)

targets::tar_assert_names(x, msg = NULL)

targets::tar_assert_nonempty(x, msg = NULL)

targets::tar_assert_null(x, msg = NULL)

targets::tar_assert_not_expr(x, msg = NULL)

targets::tar_assert_nzchar(x, msg = NULL)

targets::tar_assert_package(package, msg = NULL)

targets::tar_assert_path(path, msg = NULL)

targets::tar_assert_match(x, pattern, msg = NULL)

targets::tar_assert_nonmissing(x, msg = NULL)

targets::tar_assert_positive(x, msg = NULL)

targets::tar_assert_scalar(x, msg = NULL)

targets::tar_assert_store(store)

targets::tar_assert_targets::target(x, msg = NULL)

targets::tar_assert_targets::target_list(x)

targets::tar_assert_true(x, msg = NULL)

targets::tar_assert_unique(x, msg = NULL)

targets::tar_assert_unique_targets::targets(x)
```

### Examples

```R
tar_assert_chr("123") #succeeds invisbly
try(tar_assert_chr(123))
#> Error : 123 must be a character.
```

