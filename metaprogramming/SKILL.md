---
name: r-metaprogramming
description: >
  Use when writing R code that manipulates expressions, builds code
  programmatically, or needs to understand rlang's defuse/inject mechanics.
  Covers: defusing with expr()/enquo()/enquos(), quosure environment tracking,
  injection with !!/!!!/{{, symbol construction with sym()/syms(). Does NOT
  cover: data-mask programming patterns (tidy-evaluation), error handling
  (rlang-conditions), function design (designing-tidy-r-functions).
dependencies: R>=4.3, rlang>=1.1.3
---

# R Metaprogramming with rlang

Metaprogramming is the ability to defuse, create, and inject R expressions. The core pattern is **defuse-and-inject**: capture code as data, optionally transform it, then inject it into another context for evaluation.

## Quick Reference

| Task | Function/Operator |
|------|-------------------|
| Defuse your own expression | `expr(x + 1)` |
| Defuse user's single argument | `enquo(arg)` |
| Defuse user's `...` arguments | `enquos(...)` |
| Inject single expression | `!!` or `{{` |
| Splice list of expressions | `!!!` |
| Get expression from quosure | `quo_get_expr(q)` |
| Get environment from quosure | `quo_get_env(q)` |
| Build symbol from string | `sym("name")` |
| Build symbol with .data pronoun | `data_sym("name")` |
| Build symbols from vector | `syms(names)` / `data_syms(names)` |
| Auto-label expression | `as_label(quo)` |
| Format argument as string | `englue("{{ x }}")` |
| Interpolate name in dynamic dots | `"{name}" := value` |
| Interpolate argument in name | `"{{ arg }}" := value` |

## Defusing Expressions

Defusing stops evaluation and returns the expression as a tree-like object (a "blueprint" for computation).

```r
# Normal evaluation returns result
1 + 1
#> [1] 2

# Defusing returns the expression
expr(1 + 1)
#> 1 + 1
```

### expr() vs enquo()

| Function | Defuses | Returns | Use When |
|----------|---------|---------|----------|
| `expr()` | Your own code | Expression | Building expressions locally |
| `enquo()` | User's argument | Quosure | Forwarding function arguments |
| `enquos()` | User's `...` | List of quosures | Forwarding multiple arguments |

```r
# Defuse your own expression
my_expr <- expr(mean(x, na.rm = TRUE))

# Defuse user's function argument (returns quosure)
my_function <- function(var) {

  enquo(var)
}
my_function(cyl + am)
#> <quosure>
#> expr: ^cyl + am
#> env:  global
```

### enquos() with .named

Auto-label unnamed arguments:

```r
g <- function(...) {

  vars <- enquos(..., .named = TRUE)
  names(vars)
}
g(cyl, 1 + 1)
#> [1] "cyl"   "1 + 1"

g(foo = cyl, bar = 1 + 1)
#> [1] "foo" "bar"
```

### Types of Defused Expressions

- **Calls**: `f(x, y)`, `1 + 1` - function invocations
- **Symbols**: `x`, `df` - named object references
- **Constants**: `1`, `"text"`, `NULL` - literal values

## Quosures

A quosure wraps an expression with its original environment. This is critical for correct evaluation when expressions travel across function and package boundaries.

### Why Environments Matter

```r
# In package A
my_function <- function(data, var) {
  # 'var' was defined in the user's environment
  # The quosure tracks that environment
  var <- enquo(var)

  # When passed to package B's function, the quosure
  # ensures symbols resolve in the correct environment
  pkg_b_function(data, !!var)
}
```

Without environment tracking, symbols might resolve to wrong objects when code crosses package boundaries.

### When You Need Quosures

| Situation | Use Quosure? |
|-----------|--------------|
| Defusing function arguments | Yes - use `enquo()` |
| Building local expressions | No - use `expr()` |
| Cross-package composition | Yes - environments matter |
| Simple local evaluation | No - `expr()` + `eval()` suffices |

### Quosure Operations

```r
q <- enquo(x + 1)

quo_get_expr(q)   # Extract expression: x + 1
quo_get_env(q)    # Extract environment

# Create quosure manually
new_quosure(expr(x + 1), env = global_env())

# Convert expression to quosure
as_quosure(expr(x + 1), env = global_env())
```

## Injection Operators

Injection inserts defused expressions back into code before evaluation.

### `{{` (Embrace)

Defuses and injects in one step. Equivalent to `!!enquo(arg)`:

```r
# These are equivalent:
my_summarise <- function(data, var) {

  data |> dplyr::summarise({{ var }})
}

my_summarise <- function(data, var) {
  data |> dplyr::summarise(!!enquo(var))
}
```

Use `{{` when you simply need to forward an argument. Use `enquo()` + `!!` when you need to inspect or transform the expression first.

### `!!` (Bang-Bang)

Injects a single expression:

```r
var <- expr(cyl)
mtcars |> dplyr::summarise(mean(!!var))
#> Equivalent to: summarise(mean(cyl))

# Inject a value to avoid name collisions
x <- 100
df |> dplyr::mutate(x = x / !!x)
#> Uses column x divided by env value 100
```

### `!!!` (Splice)

Injects each element of a list as separate arguments:

```r
vars <- exprs(cyl, am, vs)
mtcars |> dplyr::select(!!!vars)
#> Equivalent to: select(cyl, am, vs)

# With enquos()
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(!!!enquos(...))
}
```

### Where Operators Work

- **Data-masked arguments**: Implicitly enabled (dplyr, ggplot2, etc.)
- **inject()**: Explicitly enables operators in any context
- **Dynamic dots**: `!!!` and `{name}` work in functions using `list2()`

```r
# Enable injection in base functions
inject(
  with(mtcars, mean(!!sym("cyl")))
)
```

## Building Expressions from Data

### sym() and syms()

Convert strings to symbols:

```r
var <- "cyl"
sym(var)
#> cyl

vars <- c("cyl", "am")
syms(vars)
#> [[1]]
#> cyl
#> [[2]]
#> am
```

### data_sym() and data_syms()

Create `.data$col` expressions (safer in tidy eval, avoids collisions):

```r
data_sym("cyl")
#> .data$cyl

data_syms(c("cyl", "am"))
#> [[1]]
#> .data$cyl
#> [[2]]
#> .data$am
```

Use `sym()` for base R functions; use `data_sym()` for tidy eval functions.

### Building Calls

```r
# With call()
call("mean", sym("x"), na.rm = TRUE)
#> mean(x, na.rm = TRUE)

# With expr() and injection
var <- sym("x")
expr(mean(!!var, na.rm = TRUE))
#> mean(x, na.rm = TRUE)
```

## Name Interpolation (Glue Operators)

In dynamic dots, use glue syntax for names.

### `{` for Variable Values

```r
name <- "foo"
tibble::tibble("{name}" := 1:3)
#> # A tibble: 3 x 1
#>     foo
#>   <int>
#> 1     1
#> 2     2
#> 3     3

tibble::tibble("prefix_{name}" := 1:3)
#> Column named: prefix_foo
```

### `{{` for Argument Labels

```r
my_mutate <- function(data, var) {
  data |> dplyr::mutate("mean_{{ var }}" := mean({{ var }}))
}
mtcars |> my_mutate(cyl)
#> Creates column: mean_cyl
```

### englue() for String Formatting

```r
my_function <- function(var) {
  englue("Column: {{ var }}")
}
my_function(some_column)
#> [1] "Column: some_column"
```

## Advanced: Manual Expression Transformation

When you need to modify expressions before injection:

```r
my_mean <- function(data, var) {
  # 1. Defuse

  var <- enquo(var)

  # 2. Transform: wrap in mean()
  wrapped <- expr(mean(!!var, na.rm = TRUE))

  # 3. Inject
  data |> dplyr::summarise(mean = !!wrapped)
}
```

For multiple arguments:

```r
my_mean <- function(.data, ...) {
  vars <- enquos(..., .named = TRUE)

  # Transform each expression
  vars <- purrr::map(vars, ~ expr(mean(!!.x, na.rm = TRUE)))

  .data |> dplyr::summarise(!!!vars)
}
```

## Base R Equivalents

| rlang | Base R | Notes |
|-------|--------|-------|
| `expr()` | `bquote()` | bquote uses `.()` for injection |
| `enquo()` | `substitute()` | substitute returns naked expr, not quosure |
| `enquos(...)` | `eval(substitute(alist(...)))` | Workaround for dots |
| `!!` | `.()` in bquote | Only inside bquote |
| `eval_tidy()` | `eval()` | eval_tidy supports .data/.env pronouns |

## Pitfalls

### `{{` on Non-Arguments

`{{` should only wrap function arguments. On regular objects, it captures the value, not the expression:

```r
# Correct: var is a function argument
my_fn <- function(var) {{ var }}

# Problematic: x is not an argument
x <- 1
{{ x }}  # Returns 1, not the expression
```

### Operators Out of Context

Outside tidy eval/inject contexts, operators have different meanings:

| Operator | Intended | Outside Context |
|----------|----------|-----------------|
| `{{` | Embrace | Double braces (returns value) |
| `!!` | Inject | Double negation (logical) |
| `!!!` | Splice | Triple negation (logical) |

These fail silently. See [topic-inject-out-of-context.Rmd](topic-inject-out-of-context.Rmd).

## See Also

- **tidy-evaluation**: Programming patterns for data-masked functions
- **designing-tidy-r-functions**: Function API design principles
- **rlang-conditions**: Error handling with rlang

## Reference Files

- [topic-defuse.Rmd](topic-defuse.Rmd) - Detailed defusing documentation
- [topic-quosure.Rmd](topic-quosure.Rmd) - Complete quosure reference
- [topic-inject.Rmd](topic-inject.Rmd) - Injection operator details
- [topic-metaprogramming.Rmd](topic-metaprogramming.Rmd) - Advanced transformation patterns
- [glue-operators.Rmd](glue-operators.Rmd) - Name interpolation reference
- [topic-multiple-columns.Rmd](topic-multiple-columns.Rmd) - Multiple columns patterns
- [topic-embrace-constants.Rmd](topic-embrace-constants.Rmd) - Constants behavior
