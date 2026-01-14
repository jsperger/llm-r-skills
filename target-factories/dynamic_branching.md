## Dynamic Branching Patterns
* `map()`: one branch per tuple of elements.
* `cross()`: one branch per *combination* of elements.
* `slice()`: select individual pieces to branch over. For example, `pattern = slice(x, index = c(3, 4))` branches over the third and fourth slices (or branches) of target `x`.
* `head()`: branch over the first few elements.
* `tail()`: branch over the last few elements.
* `sample()`: branch over a random subset of elements.

Patterns are composable. For example, `pattern = cross(other_parameter, map(fixed_radius, cycling_radius))` is conceptually equivalent to `tidyr::crossing(other_parameter, tidyr::nesting(fixed_radius, cycling_radius))`. 

## Iteration
### Vector iteration
The `iteration` argument of `tar_target()` determines how to split non-dynamic targets and how to aggregate dynamic ones. There are two major types of iteration: `"vector"` (default) and `"list"`. There is also `iteration = "group"` for branching over row groups.

Vector iteration uses the `vctrs` package to intelligently split and combine dynamic branches based on the underlying type of the object
1. `vctrs::vec_slice()` intelligently splits the non-dynamic targets for branching.
2. `vctrs::vec_c()` implicitly combines branches when you reference a dynamic target as a whole.

### List iteration
`iteration = "list"` uses `[[` to split non-dynamic targets and `list()` to combine dynamic branches. 

### Row group iteration
To dynamically branch over `dplyr::group_by()` row groups of a non-dynamic data frame, use `iteration = "group"` together with `tar_group()`. The target with `iteration = "group"` must not already be a dynamic target. (In other words, it is invalid to set `iteration = "group"` and `pattern = map(...)` for the same target.)

## Prototyping
You can test and experiment with branching structures using [`tar_pattern()`](https://docs.ropensci.org/targets/reference/tar_pattern.html). In the output below, suffixes `_1`, `_2`, and `_3`, denote both dynamic branches and the slices of upstream data they branch over.

```{r, eval = TRUE}
tar_pattern(
  cross(other_parameter, map(fixed_radius, cycling_radius)),
  other_parameter = 3,
  fixed_radius = 2,
  cycling_radius = 2
)
```

