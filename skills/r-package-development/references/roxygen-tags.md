# roxygen2 Tag Reference

## Documentation Tags

### Basic Structure

```r
#' Title (first line, no period)
#'
#' Description paragraph. Can span multiple lines.
#' Explain what the function does and when to use it.
#'
#' @details
#' Optional detailed information. Use for:
#' - Extended explanations
#' - Technical notes
#' - Algorithm descriptions
```

### Parameters

```r
#' @param x A numeric vector of values to process.
#' @param na.rm Logical. Remove `NA` values before computation? Default: `FALSE`.
#' @param ... Additional arguments passed to [underlying_function()].
#' @param .data A data frame (passed via pipe).
```

**Conventions:**
- Start with capital letter
- Describe type if not obvious
- Note default values
- For `...`, explain where arguments go

### Return Values

```r
#' @return A data frame with columns:
#'   - `id`: Row identifier
#'   - `value`: Computed result
#'   - `status`: One of "success", "warning", or "error"

#' @return A list with components:
#' \describe{
#'   \item{result}{The computed value}
#'   \item{diagnostics}{Additional information}
#' }

#' @return `NULL` invisibly. Called for side effects.
```

### Examples

```r
#' @examples
#' # Basic usage
#' my_function(1:10)
#'
#' # With options
#' my_function(1:10, na.rm = TRUE)
#'
#' \dontrun{
#' # Requires external resource
#' my_function(fetch_data())
#' }
#'
#' \donttest{
#' # Slow example, skip on CRAN
#' my_function(large_dataset)
#' }
#'
#' if (interactive()) {
#'   # Only run interactively
#'   my_function_with_prompts()
#' }
```

## Export and Import Tags

### Exporting

```r
#' @export
my_public_function <- function() { }

#' @keywords internal
my_internal_function <- function() { }

#' @exportS3Method
print.myclass <- function(x, ...) { }

#' @exportClass MyS4Class
#' @exportMethod myMethod
```

### Importing

```r
#' @import dplyr
#' @importFrom rlang .data !! !!!
#' @importFrom magrittr %>%
#' @importClassesFrom Matrix dgCMatrix
#' @importMethodsFrom methods show
```

**Best practice:** Prefer `@importFrom` over `@import` to avoid namespace pollution.

## Cross-Reference Tags

### Linking

```r
#' @seealso
#' [other_function()] for related functionality.
#' [pkg::external_function()] for the underlying implementation.
#'
#' Other transformation functions:
#' [transform_a()], [transform_b()]

#' @family transformation functions
```

### Inheritance

```r
#' @inheritParams base_function
#' @inheritDotParams base_function
#' @inheritSection source_function Section Name
```

### Aliases and Concepts

```r
#' @aliases old_function_name
#' @concept data manipulation
#' @keywords manip
```

## Formatting Tags

### Text Formatting

```r
#' Use `code formatting` for inline code.
#' Use **bold** for emphasis.
#' Use *italics* sparingly.
#'
#' Code blocks:
#' ```
#' multi_line_code()
#' more_code()
#' ```
#'
#' Or with R highlighting:
#' ```{r}
#' example_code()
#' ```
```

### Lists

```r
#' Unordered list:
#' - First item
#' - Second item
#'   - Nested item
#'
#' Ordered list:
#' 1. First step
#' 2. Second step
#'
#' Definition list:
#' \describe{
#'   \item{term1}{Definition of term1}
#'   \item{term2}{Definition of term2}
#' }
```

### Tables

```r
#' | Column 1 | Column 2 |
#' |----------|----------|
#' | Value A  | Value B  |
#' | Value C  | Value D  |
```

### Sections

```r
#' @section Custom Section:
#' Content of custom section.
#'
#' Can include multiple paragraphs.
#'
#' @section Another Section:
#' More content.
```

## Special Documentation

### Package Documentation

In `R/packagename-package.R`:

```r
#' packagename: Brief description
#'
#' Longer description of what the package provides.
#'
#' @section Main functions:
#' - [main_function()]: Does the main thing
#' - [helper_function()]: Helps with stuff
#'
#' @docType package
#' @name packagename-package
#' @keywords internal
"_PACKAGE"
```

### Data Documentation

In `R/data.R`:

```r
#' Sample dataset for examples
#'
#' A dataset containing example data for package demonstrations.
#'
#' @format A data frame with 100 rows and 3 variables:
#' \describe{
#'   \item{id}{Unique identifier}
#'   \item{value}{Numeric measurement}
#'   \item{category}{Factor with levels A, B, C}
#' }
#' @source Simulated data
"sample_data"
```

### Re-exported Functions

```r
#' @importFrom magrittr %>%
#' @export
magrittr::`%>%`

#' @importFrom rlang .data
#' @export
rlang::.data
```

### Deprecated Functions

```r
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [new_function()] instead.
#'
#' @keywords internal
old_function <- function() {
  lifecycle::deprecate_warn("1.0.0", "old_function()", "new_function()")
  new_function()
}
```

## R Markdown Features

Enable in DESCRIPTION:

```
Roxygen: list(markdown = TRUE)
```

Then use:

```r
#' # Heading
#'
#' Regular **markdown** with `code` and [links](url).
#'
#' - Bullet points
#' - Work naturally
#'
#' ```r
#' # Code blocks
#' example()
#' ```
```

## Common Patterns

### Factory Function

```r
#' Create a customized processor
#'
#' @param config Configuration list with options.
#' @return A function that processes data according to config.
#' @export
#' @examples
#' processor <- create_processor(list(verbose = TRUE))
#' processor(my_data)
create_processor <- function(config) {
  function(data) {
    # Process data
  }
}
```

### Method Documentation

```r
#' Process data
#'
#' @param x Object to process.
#' @param ... Additional arguments.
#' @return Processed object.
#' @export
process <- function(x, ...) {
  UseMethod("process")
}

#' @rdname process
#' @export
process.default <- function(x, ...) {
  # Default implementation
}

#' @rdname process
#' @export
process.myclass <- function(x, ...) {
  # Specialized implementation
}
```
