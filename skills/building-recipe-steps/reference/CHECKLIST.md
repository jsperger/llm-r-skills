# Custom Step Development Checklist

## Constructor (`step_{name}`)
- [ ] Accepts `...` for variable selection via `enquos(...)`
- [ ] Has `role`, `trained`, `columns`, `skip`, `id` arguments
- [ ] `id` defaults to `recipes::rand_id("{name}")`
- [ ] Returns the recipe via `recipes::add_step()`
- [ ] Does NOT perform calculations — only stores arguments
- [ ] Has roxygen2 documentation with `@export`

## Initialization (`step_{name}_new`)
- [ ] Calls `recipes::step(subclass = "{name}", ...)`
- [ ] Accepts all arguments needed to reconstruct the object
- [ ] Not exported (internal helper)

## Prep Method (`prep.step_{name}`)
- [ ] Uses `recipes::recipes_eval_select()` to resolve selectors
- [ ] Uses `recipes::check_type()` to validate column types
- [ ] Estimates parameters from `training` data only
- [ ] Returns new step object with `trained = TRUE`
- [ ] Stores resolved `col_names` in `columns`
- [ ] Stores all estimated parameters as named fields
- [ ] Has `@export` tag

## Bake Method (`bake.step_{name}`)
- [ ] Calls `recipes::check_new_data()` to validate columns exist
- [ ] Returns a `tibble`
- [ ] Row count unchanged (unless step is specifically for filtering with `skip = TRUE`)
- [ ] Uses stored parameters from prep, never re-estimates
- [ ] Has `@export` tag

## Print Method (`print.step_{name}`)
- [ ] Uses `recipes::print_step()` for consistent formatting
- [ ] Returns `invisible(x)`
- [ ] Has `@export` tag

## Tidy Method (`tidy.step_{name}`)
- [ ] Returns a tibble with at least `terms` and `id` columns
- [ ] Handles both trained and untrained states
- [ ] Uses `recipes::sel2char()` for untrained terms
- [ ] Has `@export` tag

## Required Packages (`required_pkgs.step_{name}`)
- [ ] Returns character vector of package names needed at bake time
- [ ] Ensures parallel processing backends can load dependencies
- [ ] Has `@export` tag

## Integration
- [ ] Step works with tidyselect helpers (`all_predictors()`, `all_numeric_predictors()`)
- [ ] Step works inside a `workflow()` with `add_recipe()`
- [ ] Step survives `prep()` then `bake(new_data = NULL)` round-trip
- [ ] Step survives `prep()` then `bake(new_data = test_data)` round-trip

## Optional: Tunable Parameters
- [ ] If step has hyperparameters, define `tunable.step_{name}` method
- [ ] Return tibble with columns: `name`, `call_info`, `source`, `component`, `component_id`
- [ ] Each row maps a parameter to a `dials` function for `tune()` integration
