---
name: creating-s7-objects
description: Use when creating R classes, generics, or methods with the S7 object system. Triggers on new_class, new_generic, new_property, method(), S7_dispatch, or requests for formal R objects in packages using S7. CRITICAL disambiguation — S7 uses its own syntax, NOT S3 (no UseMethod, no structure, no $) and NOT S4 (no setClass, no setGeneric, no slots). The @ operator in S7 accesses typed properties, not S4 slots.
version: "0.1.0"

---

# S7 in R Packages

## STOP: S7 is NOT S3 or S4

S7 is a **distinct** object system. Do not use S3 or S4 patterns.

| Task | S3 (WRONG) | S4 (WRONG) | S7 (CORRECT) |
|------|-----------|-----------|--------------|
| Define class | `structure(list(), class = "Foo")` | `setClass("Foo", slots = ...)` | `Foo <- new_class("Foo", properties = ...)` |
| Create instance | manual `new_foo()` | `new("Foo", ...)` | `Foo(...)` (class IS constructor) |
| Access property | `x$name` | `x@name` (slot) | `x@name` (typed property) |
| Define generic | `function(x, ...) UseMethod("foo")` | `setGeneric("foo", ...)` | `foo <- new_generic("foo", "x")` |
| Register method | `foo.MyClass <- function(x) {}` | `setMethod("foo", "MyClass", ...)` | `method(foo, MyClass) <- function(x) {}` |
| Call parent | `NextMethod()` | `callNextMethod()` | `super(x, to = Parent)` |
| Validate | (manual) | `validObject(x)` | `validate(x)` (automatic) |
| Check class | `inherits(x, "Foo")` | `is(x, "Foo")` | `S7_inherits(x, Foo)` |

### Red Flags: You Are Using the Wrong System

If you write any of these, STOP — you are not writing S7:

- `structure()`, `class() <-`, `UseMethod()`, `NextMethod()` → These are S3
- `setClass()`, `setGeneric()`, `setMethod()`, `new()`, `callNextMethod()`,
  `representation()`, `slots =`, `contains =` → These are S4
- `x$property` for property access → S3 lists, not S7 (use `x@property`)
- `is(x, "ClassName")` → use `S7_inherits(x, ClassName)`

### The `@` Operator in S7

`@` in S7 accesses **typed properties**, not S4 slots. The syntax looks
identical to S4 but the semantics differ:

- **S4**: `@` is direct slot access — no computation, no validation
- **S7**: `@` can trigger getters, setters, and validators

Do NOT see `@` and assume S4. In S7 code, `x@name` means "access the `name`
property of S7 object `x`."

## Classes

Assign `new_class()` to a variable matching the class name. The class object
IS the constructor — call it directly to create instances. For exported
classes, always set `package`:

```r
Dog <- new_class("Dog",
  package = "mypackage",
  properties = list(
    name = class_character,
    age = class_numeric
  )
)

# Create instance by calling the class:
buddy <- Dog(name = "Buddy", age = 3)
```

Inheritance is single-parent only (no multiple inheritance):

```r
Pet <- new_class("Pet", properties = list(
  name = class_character,
  age = class_numeric
))
Dog <- new_class("Dog", parent = Pet, properties = list(
  breed = class_character
))
```

## Properties

For the complete list of built-in type classes (`class_double`, `class_Date`,
`class_numeric`, unions, etc.), see [references/type-system.md](references/type-system.md).

For S3 classes without a built-in wrapper, use `new_S3_class("data.frame")`.

### new_property() for advanced control

**Defaults**: Use `quote()` for values evaluated at construction time:

```r
start_time = new_property(class_POSIXct, default = quote(Sys.time()))
```

**Required properties** via quoted error:

```r
name = new_property(class_character, default = quote(stop("@name is required")))
```

**Property validators** return `NULL` if valid or a problem string. Omit the
property name from messages; S7 prepends it automatically:

```r
prop_positive <- new_property(
  class = class_double,
  validator = function(value) {
    if (length(value) != 1 || value <= 0) "must be a single positive number"
  }
)
```

**Computed (read-only)** via `getter`:

```r
length = new_property(
  getter = function(self) self@end - self@start
)
```

**Dynamic (read-write)** adds `setter`, which must return the modified object:

```r
length = new_property(
  class = class_double,
  getter = function(self) self@end - self@start,
  setter = function(self, value) {
    self@end <- self@start + value
    self
  }
)
```

## Class Validators

Validate cross-property constraints. Return `NULL` or a character vector of
problems:

```r
Range <- new_class("Range",
  properties = list(start = class_double, end = class_double),
  validator = function(self) {
    if (length(self@start) != 1) "@start must be length 1"
    else if (length(self@end) != 1) "@end must be length 1"
    else if (self@end < self@start) {
      sprintf("@end (%i) must be >= @start (%i)", self@end, self@start)
    }
  }
)
```

Validation runs on construction and on every property set. To update multiple
properties atomically (avoiding intermediate invalid states):

```r
props(x) <- list(start = new_start, end = new_end)
```

## Custom Constructors

Must end with `new_object()`. First argument is an instance of the parent class
(`S7_object()` when no parent is specified), followed by named property values:

```r
Range <- new_class("Range",
  properties = list(start = class_numeric, end = class_numeric),
  constructor = function(x) {
    new_object(S7_object(), start = min(x, na.rm = TRUE), end = max(x, na.rm = TRUE))
  }
)
```

Any subclass of a class with a custom constructor also requires a custom
constructor.

## Generics and Methods

Assign `new_generic()` to a variable matching the generic name. Default
signature is `function(x, ...)`:

```r
speak <- new_generic("speak", "x")
```

Custom signature must call `S7_dispatch()`:

```r
mean <- new_generic("mean", "x", function(x, ..., na.rm = TRUE) {
  S7_dispatch()
})
```

Register methods with `method(generic, class) <- implementation`. Unlike S3,
methods should generally omit `...` so misspelled arguments produce errors:

```r
method(speak, Dog) <- function(x) "Woof"
```

### super()

Delegates to a parent class method. Unlike S3's `NextMethod()` or S4's
`callNextMethod()`, S7's `super()` requires you to explicitly name the target
class. All arguments are explicit — nothing is passed automatically:

```r
describe <- new_generic("describe", "x")
method(describe, Pet) <- function(x) {
  paste0(x@name, " is ", x@age, " years old")
}
method(describe, Dog) <- function(x) {
  paste0(describe(super(x, to = Pet)), " (breed: ", x@breed, ")")
}
```

### Multiple dispatch

```r
speak <- new_generic("speak", c("x", "y"))
method(speak, list(Dog, English)) <- function(x, y) "Woof"
```

Use `class_any` to match any class, `class_missing` for unsupplied arguments.

### Debugging

`method_explain()` shows which method dispatch selects:

```r
method_explain(describe, Dog())
```

## S3/S4 Interoperability

### Methods for existing S3 generics (print, format, etc.)

Use `new_external_generic()` to register S7 methods for generics defined in
other packages:

```r
.S3_print <- new_external_generic("base", "print", "x")
method(.S3_print, Dog) <- function(x, ...) {
  cat(sprintf("A dog named %s\n", x@name))
}
```

**Important:** `super()` does not work with S3 generics. Use `S7_data()` to
access the underlying base type data:

```r
MyInt <- new_class("MyInt", parent = class_integer)
method(.S3_print, MyInt) <- function(x, ...) {
  cat("My integer:", S7_data(x), "\n")
}
```

## Package Integration

### .onLoad (required)

```r
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
```

Required when registering methods for generics in other packages; harmless
otherwise.

### Backward compatibility (R < 4.3.0)

`@` for S7 objects requires R >= 4.3.0. For older R, use `prop()` or add:

```r
#' @rawNamespace if (getRversion() < "4.3.0") importFrom("S7", "@")
NULL
```

## Reference

See [references/type-system.md](references/type-system.md) for all built-in S7
type classes, unions, S3 wrappers, and special dispatch classes.
