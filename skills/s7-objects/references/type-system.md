# S7 Built-in Type Classes

## Contents
- Base type classes
- Union classes (built-in and custom)
- S3 compatibility classes
- Special dispatch classes
- Choosing the right type

## Base Type Classes

| Class               | R type        |
|---------------------|---------------|
| `class_logical`     | `logical`     |
| `class_integer`     | `integer`     |
| `class_double`      | `double`      |
| `class_complex`     | `complex`     |
| `class_character`   | `character`   |
| `class_raw`         | `raw`         |
| `class_list`        | `list`        |
| `class_expression`  | `expression`  |
| `class_name`        | `name`        |
| `class_call`        | `call`        |
| `class_function`    | `function`    |
| `class_environment` | `environment` |

## Union Classes

| Union Class      | Member Types                                                     |
|------------------|------------------------------------------------------------------|
| `class_numeric`  | `class_integer` \| `class_double`                                |
| `class_atomic`   | `class_logical` \| `class_numeric` \| `class_complex` \| `class_character` \| `class_raw` |
| `class_vector`   | `class_atomic` \| `class_expression` \| `class_list`            |
| `class_language` | `class_name` \| `class_call`                                    |

### Custom unions

```r
class_numeric_or_null <- new_union(class_numeric, NULL)
```

`NULL` in a union makes the property nullable. Registering a method for a union
registers it for each member class.

## S3 Compatibility Classes

| Class           | S3 class(es)        |
|-----------------|---------------------|
| `class_factor`  | `factor`            |
| `class_Date`    | `Date`              |
| `class_POSIXct` | `POSIXct`, `POSIXt` |
| `class_POSIXlt` | `POSIXlt`, `POSIXt` |
| `class_POSIXt`  | `POSIXt`            |
| `class_matrix`  | `matrix`            |
| `class_array`   | `array`             |
| `class_formula` | `formula`           |

For other S3 classes: `new_S3_class("tbl_df")`.

## Special Classes

| Class           | Purpose                                    |
|-----------------|--------------------------------------------|
| `class_any`     | Matches any class in dispatch              |
| `class_missing` | Matches unsupplied argument in dispatch    |

Primarily useful in multiple dispatch. `class_any` also works as a property
type to accept any value.

## Choosing the Right Type

1. **Single R type** → matching `class_*` base type
2. **Integer or double** → `class_numeric`
3. **Any atomic** → `class_atomic`
4. **Nullable** → `new_union(class_character, NULL)`
5. **S3 class** → built-in `class_*` if available, else `new_S3_class("classname")`
6. **Another S7 class** → use the class object directly: `list(pet = Pet)`
7. **Any value** → `class_any`
8. **Computed** → `new_property(getter = ...)`
