# Condition Customisation Reference

Customize the appearance of condition messages from `abort()`, `warn()`, `inform()`, and their cli equivalents using cli package options.

## Table of Contents

1. [Unicode Bullets](#unicode-bullets)
2. [Bullet Symbols](#bullet-symbols)
3. [Error Call Colors](#error-call-colors)
4. [Setting Options](#setting-options)

## Unicode Bullets

By default, condition messages use unicode bullet symbols:

```r
rlang::abort(c(
  "The error message.",
  "*" = "Regular bullet.",
  "i" = "Informative bullet.",
  "x" = "Cross bullet.",
  "v" = "Victory bullet.",
  ">" = "Arrow bullet."
))
#> Error:
#> ! The error message.
#> * Regular bullet.
#> i Informative bullet.
#> x Cross bullet.
#> v Victory bullet.
#> > Arrow bullet.
```

### Disabling Unicode Bullets

Use simple ASCII letters instead:

```r
options(cli.condition_unicode_bullets = FALSE)

rlang::abort(c(
  "The error message.",
  "*" = "Regular bullet.",
  "i" = "Informative bullet.",
  "x" = "Cross bullet.",
  "v" = "Victory bullet.",
  ">" = "Arrow bullet."
))
#> Error:
#> ! The error message.
#> * Regular bullet.
#> i Informative bullet.
#> x Cross bullet.
#> v Victory bullet.
#> > Arrow bullet.
```

## Bullet Symbols

Customize bullet symbols through cli user themes.

### Uniform Bullets (Except Header)

Use the same symbol for all bullet types:

```r
options(cli.user_theme = list(
  ".cli_rlang .bullet-*" = list(before = "* "),
  ".cli_rlang .bullet-i" = list(before = "* "),
  ".cli_rlang .bullet-x" = list(before = "* "),
  ".cli_rlang .bullet-v" = list(before = "* "),
  ".cli_rlang .bullet->" = list(before = "* ")
))

rlang::abort(c(
  "The error message.",
  "*" = "Regular bullet.",
  "i" = "Informative bullet.",
  "x" = "Cross bullet."
))
#> Error:
#> ! The error message.
#> * Regular bullet.
#> * Informative bullet.
#> * Cross bullet.
```

### All Bullets Including Header

To change all bullets including the leading `!`:

```r
options(cli.user_theme = list(
  ".cli_rlang .bullet" = list(before = "* ")
))

rlang::abort(c(
  "The error message.",
  "*" = "Regular bullet.",
  "i" = "Informative bullet."
))
#> Error:
#> * The error message.
#> * Regular bullet.
#> * Informative bullet.
```

### Custom Symbols Per Type

Mix custom symbols:

```r
options(cli.user_theme = list(
  ".cli_rlang .bullet-x" = list(before = "[-] "),
  ".cli_rlang .bullet-v" = list(before = "[+] "),
  ".cli_rlang .bullet-i" = list(before = "[i] ")
))
```

## Error Call Colors

When `abort()` is called inside a function, it displays the function call. This is formatted as a `code` element with background highlighting.

### Default Behavior

```r
splash <- function() {
  abort("Can't splash without water.")
}

splash()
#> Error in `splash()`:
#> ! Can't splash without water.
```

The `splash()` text has a highlighted background (light or dark theme aware).

### Custom Code Colors

Override the code element styling in your cli theme:

```r
options(cli.user_theme = list(
  span.code = list(
    "background-color" = "#3B4252",
    color = "#E5E9F0"
  )
))
```

### Theme Properties

Available CSS-like properties for `span.code`:

| Property | Description | Example |
|----------|-------------|---------|
| `color` | Text color | `"#E5E9F0"` |
| `background-color` | Background color | `"#3B4252"` |
| `font-weight` | Bold/normal | `"bold"` |
| `font-style` | Italic/normal | `"italic"` |

## Setting Options

### In .Rprofile

For personal settings, add to `~/.Rprofile`:
```r
options(
  cli.condition_unicode_bullets = FALSE,
  cli.user_theme = list(
    span.code = list(
      "background-color" = "#3B4252",
      color = "#E5E9F0"
    )
  )
)
```

### In Package Code

For package defaults, set options in `.onLoad()`:

```r
.onLoad <- function(libname, pkgname) {
  # Only if not already set by user
  if (is.null(getOption("my_pkg.bullet_style"))) {
    options(my_pkg.bullet_style = "unicode")
  }
}
```

**Note**: Generally avoid overriding user's cli theme in packages. These customizations are intended for end-user configuration.

### Checking Current Settings

```r
getOption("cli.condition_unicode_bullets")
getOption("cli.user_theme")
```
