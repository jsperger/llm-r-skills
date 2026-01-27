---
name: r-languageserver
description: >
  This skill should be used when navigating R code, finding function definitions,
  understanding call hierarchies, exploring package dependencies, or performing
  impact analysis before refactoring R code. Covers LSP operations: hover,
  goToDefinition, findReferences, documentSymbol, workspaceSymbol, incomingCalls,
  outgoingCalls, and prepareCallHierarchy.
---

# R Language Server Protocol Integration

The R languageserver provides code intelligence for R files through the LSP tool. Use these capabilities as a "sensor array" for understanding R codebases—retrieving documentation, navigating definitions, and analyzing call graphs without reading entire files.

## Available Operations

| Operation | Purpose | Primary Use Case |
|-----------|---------|------------------|
| `hover` | Get documentation | Understanding function contracts |
| `goToDefinition` | Jump to definition | Navigating to function source |
| `findReferences` | Find all usages | Impact analysis before changes |
| `documentSymbol` | List file symbols | File structure overview |
| `workspaceSymbol` | Search all symbols | Finding functions across project |
| `incomingCalls` | What calls this? | Understanding dependencies |
| `outgoingCalls` | What does this call? | Understanding execution flow |
| `prepareCallHierarchy` | Initialize call tree | Preparing for call analysis |

### Not Supported

`goToImplementation` is not implemented by R languageserver. Use `goToDefinition` instead.

## Critical Concept: Character Positioning

**The most common cause of failed LSP operations is incorrect character positioning.**

All operations require precise cursor placement ON the symbol:

```r
# Line 15:   result <- MyFunction(data, config)
#            ^        ^         ^
#            col 3    col 14    col 25
```

- Position on `result` (col 3-8): References to this variable
- Position on `MyFunction` (col 14-23): Definition/references of the function
- Position on `data` (col 25-28): References to the argument

When an operation returns "no definition found" or "no hover information," adjust the character position before assuming the symbol isn't indexed.

## Core Workflows

### 1. File Structure Before Reading

Instead of reading a 500-line file to find one function, use `documentSymbol` first:

```
LSP documentSymbol on large_file.R
→ Returns: FunctionA (Line 45), FunctionB (Line 120), FunctionC (Line 280)
→ Then: Read file with offset=118, limit=50 to see just FunctionB
```

This retrieves the file's "sitemap" and enables targeted reading.

**Note:** R languageserver also indexes comment-based section markers (`# ====`, `# ----`, `# ---- Section Name ----`). These appear in documentSymbol output, useful for navigating large files organized with sections.

### 2. Understanding External Functions

When encountering an unfamiliar function from an external package, use `hover`:

```
LSP hover on purrr::map_lgl at line 48, character 20
→ Returns: Full documentation with description, parameters, return value, examples
```

This retrieves package documentation without web searches or leaving the editor. Hover works for:
- Base R functions (`summary`, `grep`, `setdiff`)
- Tidyverse and other CRAN packages
- Locally defined functions (when called, not at definition site)
- Unexported functions accessed via `:::` (shows signature only)

### 3. Impact Analysis Before Modifying

Before changing a function's signature or behavior, use `incomingCalls` to find all callers:

```
LSP incomingCalls on ProcessData at line 50, character 1
→ Returns:
  - targets/pipeline.R: run_analysis (Line 30) [calls at: 45:5]
  - R/helpers.R: batch_process (Line 80) [calls at: 92:12]
  - tests/test-process.R: test cases (Lines 15, 28, 41)
```

This reveals the blast radius of any change. The output includes:
- File paths of callers
- Function/target names containing the calls
- Exact line and column of each call site

### 4. Understanding Execution Flow

To understand what a function depends on, use `outgoingCalls`:

```
LSP outgoingCalls on FitModel at line 100, character 1
→ Returns:
  - validate_input (local) [called from: 105:3]
  - checkmate::assert_class [called from: 106:3, 107:3]
  - recipes::prep [called from: 115:12]
  - parsnip::fit [called from: 120:12]
```

This maps the function's dependencies, showing:
- Which functions are called
- Whether they're local or from packages
- Every call site within the function

### 5. Cross-File Navigation

To find where a symbol is used across the entire project, use `findReferences`:

```
LSP findReferences on helper_function at line 25, character 1
→ Returns:
  - R/helpers.R: Line 25:1 (definition)
  - R/main.R: Line 45:12, Line 78:8
  - tests/test-helpers.R: Line 12:5, Line 30:5
```

References work across:
- Package R/ source files
- Test files
- targets/ pipeline definitions
- Any .R file in the workspace

### 6. Finding Functions Project-Wide

To locate a function without knowing which file contains it, use `workspaceSymbol`:

```
LSP workspaceSymbol (from any R file)
→ Returns all indexed symbols:
  - R/data.R: ProcessData (Function) - Line 15
  - R/models.R: FitModel (Function) - Line 42
  - R/utils.R: validate_input (Function) - Line 8
  - targets/pipeline.R: data_tar (Field) - Line 5
```

The current implementation returns all indexed symbols without query filtering. Scan the output or use Grep as a fallback for large workspaces.

## Behavior Notes

### Installed vs. Non-Installed Packages

The LSP reads source from the workspace, not from installed packages. Both installed local packages and non-installed packages in the workspace work identically for all operations.

### External Package Definitions

When `goToDefinition` resolves to an external package (CRAN, tidyverse, etc.), the definition points to a temporary file:

```
/var/folders/.../RtmpXXXXX/function_name.R
```

This is extracted source code from the installed package. The content is readable and accurate but the path is ephemeral.

### Diagnostics as Side Effects

When accessing files through LSP operations, the languageserver may publish diagnostics (lintr warnings) as side effects. These appear in tool output as `<new-diagnostics>` blocks. This behavior cannot be explicitly requested—it occurs automatically during file indexing.

Common diagnostics include:
- `implicit_integer_linter`: Use `1L` instead of `1`
- `line_length_linter`: Lines over 80 characters
- `undesirable_operator_linter`: Warnings about `:::`

### Workspace Indexing

Some operations require files to be "seen" by the LSP before they're fully indexed. If `findReferences` or `workspaceSymbol` returns incomplete results, access the relevant files first (via any LSP operation) to trigger indexing.

## When to Use LSP vs Other Tools

| Task | Preferred Approach |
|------|-------------------|
| Find function definition (external package) | `goToDefinition` |
| Find function definition (local, known file) | `Grep` or `Read` |
| Get function documentation | `hover` |
| List functions in a file | `documentSymbol` |
| Find all usages of a function | `findReferences` |
| Search for function by name | `workspaceSymbol` or `Grep` |
| Understand what calls a function | `incomingCalls` |
| Understand what a function calls | `outgoingCalls` |
| Read function implementation | `Read` with offset/limit |
| Search for text patterns | `Grep` |

## Quick Reference

### Operation Parameters

All operations require:
- `filePath`: Absolute path to an R file
- `line`: 1-based line number
- `character`: 1-based character offset

### Successful Output Patterns

**hover:** Returns markdown-formatted documentation with signature, description, parameters, and examples.

**goToDefinition:** Returns `Defined in path/to/file.R:line:column`

**findReferences:** Returns `Found N references across M files:` followed by file paths and line numbers.

**documentSymbol:** Returns `Found N symbols in workspace:` followed by function names, types, and line numbers.

**incomingCalls/outgoingCalls:** Returns `Found N calls:` with caller/callee information and call site locations.

### Failure Patterns

- "No definition found" → Check character position; ensure cursor is ON the symbol
- "No hover information" → Symbol may be at definition site (hover works on calls, not definitions for local functions)
- "No references found" → File may not be indexed; try accessing it first
- "LSP request failed" → Operation not supported (e.g., `goToImplementation`)
