# Metaprogramming Patterns

The patterns covered in this article rely on _metaprogramming_, the ability to defuse, create, expand, and inject R expressions. A good place to start if you're new to programming on the language is the [Metaprogramming chapter](https://adv-r.hadley.nz/metaprogramming.html) of the [Advanced R](https://adv-r.hadley.nz) book.

If you haven't already, read the data mask programming topic which covers simpler patterns that do not require as much theory to get up to speed. It covers concepts like argument behaviours and the various patterns you can add to your toolbox (forwarding, names, bridge, and transformative patterns).


## Forwarding patterns

### Defuse and inject

`{{` and `...` are sufficient for most purposes. Sometimes however, it is necessary to decompose the forwarding action into its two constitutive steps, defusing and injecting.

`{{` is the combination of `enquo()` and `!!`. These functions are completely equivalent:

```r
my_summarise <- function(data, var) {
  data |> dplyr::summarise({{ var }})
}
my_summarise <- function(data, var) {
  data |> dplyr::summarise(!!enquo(var))
}
```

Passing `...` is equivalent to the combination of `enquos()` and `!!!`:

```r
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(...)
}
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(!!!enquos(...))
}
```

The advantage of decomposing the steps is that you gain access to the defused expressions. Once defused, you can inspect or modify the expressions before injecting them in their target context.


### Inspecting input labels

For instance, here is how to create an automatic name for a defused argument using `as_label()`:

```r
f <- function(var) {
  var <- enquo(var)
  as_label(var)
}

f(cyl)
#> [1] "cyl"

f(1 + 1)
#> [1] "1 + 1"
```

This is essentially equivalent to formatting an argument using `englue()`:

```r
f2 <- function(var) {
  englue("{{ var }}")
}

f2(1 + 1)
#> [1] "1 + 1"
```

With multiple arguments, use the plural variant `enquos()`. Set `.named` to `TRUE` to automatically call `as_label()` on the inputs for which the user has not provided a name (the same behaviour as in most dplyr verbs):

```r
g <- function(...) {
  vars <- enquos(..., .named = TRUE)
  names(vars)
}

g(cyl, 1 + 1)
#> [1] "cyl"   "1 + 1"
```

Just like with `dplyr::mutate()`, the user can override automatic names by supplying explicit names:

```r
g(foo = cyl, bar = 1 + 1)
#> [1] "foo" "bar"
```

Defuse-and-inject patterns are most useful for transforming inputs. Some applications are explored in the Transformation patterns section.


## Names patterns

### Symbolise and inject

The symbolise-and-inject pattern is a _names pattern_ that you can use when `across(all_of())` is not supported. It consists in creating defused expressions that refer to the data-variables represented in the names vector. These are then injected in the data mask context.

Symbolise a single string with `sym()` or `data_sym()`:

```r
var <- "cyl"

sym(var)
#> cyl

data_sym(var)
#> .data$cyl
```

Symbolise a character vector with `syms()` or `data_syms()`.

```r
vars <- c("cyl", "am")

syms(vars)
#> [[1]]
#> cyl
#>
#> [[2]]
#> am

data_syms(vars)
#> [[1]]
#> .data$cyl
#>
#> [[2]]
#> .data$am
```

Simple symbols returned by `sym()` and `syms()` work in a wider variety of cases (with base functions in particular) but we'll use mostly use `data_sym()` and `data_syms()` because they are more robust (see the data mask ambiguity topic). Note that these do not return _symbols_ per se, instead they create _calls_ to `$` that subset the `.data` pronoun.

Since the `.data` pronoun is a tidy eval feature, you can't use it in base functions. As a rule, prefer the `data_`-prefixed variants when you're injecting in tidy eval functions and the unprefixed functions for base functions.

A list of symbols can be injected in data-masked dots with the splice operator `!!!`, which injects each element of the list as a separate argument. For instance, to implement a `group_by()` variant that takes a character vector of column names, you might write:

```r
my_group_by <- function(data, vars) {
  data |> dplyr::group_by(!!!data_syms(vars))
}

my_group_by(vars)
```

In more complex case, you might want to add R code around the symbols. This requires _transformation_ patterns, see the section below.


## Bridge patterns

### `mutate()` as a data-mask to selection bridge

This is a variant of the `transmute()` bridge pattern described in the data mask programming topic that does not materialise `...` in the intermediate step. Instead, the `...` expressions are defused and inspected. Then the expressions, rather than the columns, are spliced in `mutate()`.

```r
my_pivot_longer <- function(data, ...) {
  # Defuse the dots and inspect the names
  dots <- enquos(..., .named = TRUE)
  names <- names(dots)

  # Pass the inputs to `mutate()`
  data <- data |> dplyr::mutate(!!!dots)

  # Select `...` inputs by name with `all_of()`
  data |>
    tidyr::pivot_longer(cols = all_of(names))
}

mtcars |> my_pivot_longer(cyl, am = am * 100)
```

1. Defuse the `...` expressions. The `.named` argument ensures unnamed inputs get a default name, just like they would if passed to `mutate()`. Take the names of the list of inputs.

2. Once we have the names, inject the argument expressions into `mutate()` to update the data frame.

3. Finally, pass the names to the tidy selection via `all_of()`.


## Transformation patterns

### Transforming inputs manually

If `across()` and variants are not available, you will need to transform the inputs yourself using metaprogramming techniques. To illustrate the technique we'll reimplement `my_mean()` and without using `across()`. The pattern consists in defusing the input expression, building larger calls around them, and finally inject the modified expressions inside the data-masking functions.

We'll start with a single named argument for simplicity:

```r
my_mean <- function(data, var) {
  # Defuse the expression
  var <- enquo(var)

  # Wrap it in a call to `mean()`
  var <- expr(mean(!!var, na.rm = TRUE))

  # Inject the expanded expression
  data |> dplyr::summarise(mean = !!var)
}

mtcars |> my_mean(cyl)
#> # A tibble: 1 x 1
#>    mean
#>   <dbl>
#> 1  6.19
```

With `...` the technique is similar, though a little more involved. We'll use the plural variants `enquos()` and `!!!`. We'll also loop over the variable number of inputs using `purrr::map()`. But the pattern is otherwise basically the same:

```r
my_mean <- function(.data, ...) {
  # Defuse the dots. Make sure they are automatically named.
  vars <- enquos(..., .named = TRUE)

  # Map over each defused expression and wrap it in a call to `mean()`
  vars <- purrr::map(vars, ~ expr(mean(!!.x, na.rm = TRUE)))

  # Inject the expressions
  .data |> dplyr::summarise(!!!vars)
}

mtcars |> my_mean(cyl)
#> # A tibble: 1 x 1
#>     cyl
#>   <dbl>
#> 1  6.19
```

Note that we are inheriting the data-masking behaviour of `summarise()` because we have effectively forwarded `...` inside that verb. This is different than transformation patterns based on `across()` which inherit tidy selection behaviour. In practice, this means the function doesn't support selection helpers and syntax. Instead, it gains the ability to create new vectors on the fly:

```r
mtcars |> my_mean(cyl = cyl * 100)
#> # A tibble: 1 x 1
#>     cyl
#>   <dbl>
#> 1  619.
```


## Base patterns

In this section, we review patterns for programming with _base_ data-masking functions. They essentially consist in building and evaluating expressions in the data mask. We review these patterns and compare them to rlang idioms.


### Data-masked `get()`

In the simplest version of this pattern, `get()` is called with a variable name to retrieve objects from the data mask:

```r
var <- "cyl"

with(mtcars, mean(get(var)))
#> [1] 6.1875
```

This sort of pattern is susceptible to names collisions. For instance, the input data frame might contain a variable called `var`:

```r
df <- data.frame(var = "wrong")

with(df, mean(get(var)))
#> Error in mean.default(get(var)): argument is not numeric or logical:
#>   returning NA
```

In general, prefer symbol injection over `get()` to prevent this sort of collisions. With base functions you will need to enable injection operators explicitly using `inject()`:

```r
inject(
  with(mtcars, mean(!!sym(var)))
)
#> [1] 6.1875
```

See the data mask ambiguity topic for more information about names collisions.


### Data-masked `parse()` and `eval()`

A more involved pattern consists in building R code in a string and evaluating it in the mask:

```r
var1 <- "am"
var2 <- "vs"

code <- paste(var1, "==", var2)
with(mtcars, mean(eval(parse(text = code))))
#> [1] 0.59375
```

As before, the `code` variable is vulnerable to names collisions. More importantly, if `var1` and `var2` are user inputs, they could contain adversarial code. Evaluating code assembled from strings is always a risky business:

```r
var1 <- "(function() {
  Sys.sleep(Inf)  # Could be a coin mining routine
})()"
var2 <- "vs"

code <- paste(var1, "==", var2)
with(mtcars, mean(eval(parse(text = code))))
```

This is not a big deal if your code is only used internally. However, this code could be part of a public Shiny app which Internet users could exploit. But even internally, parsing is a source of bugs when variable names contain syntactic symbols like `-` or `:`.

```r
var1 <- ":var:"
var2 <- "vs"

code <- paste(var1, "==", var2)
with(mtcars, mean(eval(parse(text = code))))
#> Error in parse(text = code): <text>:1:1: unexpected ':'
```

For these reasons, always prefer to _build_ code instead of parsing code. Building variable names with `sym()` is a way of sanitising inputs.

```r
var1 <- "(function() {
  Sys.sleep(Inf)  # Could be a coin mining routine
})()"
var2 <- "vs"

code <- call("==", sym(var1), sym(var2))

code
#> `(function() {\n  Sys.sleep(Inf)
#> })()` == vs
```

The adversarial input now produces an error:

```r
with(mtcars, mean(eval(code)))
#> Error in eval(code): object '(function() {\n
#>   Sys.sleep(Inf)  # Could be a coin mining routine\n})()' not found
```

Finally, it is recommended to inject the code instead of evaluating it to avoid names collisions:

```r
var1 <- "am"
var2 <- "vs"

code <- call("==", sym(var1), sym(var2))
inject(
  with(mtcars, mean(!!code))
)
#> [1] 0.59375
```
