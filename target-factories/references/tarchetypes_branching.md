## 1. Dynamic Data Frame Grouping
Use these when you have a large data frame and want to branch over rows/groups without manually splitting files.

| Function | Strategy |
| :--- | :--- |
| `tarchetypes::tar_group_by()` | Group by specific variables (e.g., `site`, `year`). |
| `tarchetypes::tar_group_count()` | Split data into `N` equal-sized batches. |
| `tarchetypes::tar_group_size()` | Split data into batches of exactly `X` rows. |

## 2. Batched Replication (Simulations)
Standard dynamic branching has high overhead for thousands of small tasks. Batched replication runs multiple "reps" within a single worker process.

- **`tarchetypes::tar_rep()`**: Run a command `N` times. Best for MCMC or bootstrap loops.
- **`tarchetypes::tar_map_rep()`**: The "Hybrid." Static branching (e.g., different scenarios) combined with dynamic batched replication within each scenario.
- **`tarchetypes::tar_rep_index()`**: Utility to retrieve the specific iteration index within a batch.

Static branching
tar_combine() Static aggregation.
tar_map() Static branching.

Dynamic grouped data frames
tar_group_by() Group a data frame target by one or more variables.
tar_group_count() Group the rows of a data frame into a given number groups
tar_group_select() Group a data frame target with tidyselect semantics.
tar_group_size() Group the rows of a data frame into groups of a given size.

Dynamic batched replication
tar_rep()  Batched replication with dynamic branching.

Dynamic batched replication within static branches for data frames
tar_map_rep() Dynamic batched replication within static branches for data frames.
