# Startup profile for agent LSP sessions. Delivered via the plugin's .lsp.json:
#   "env": { "R_PROFILE_USER": "${CLAUDE_PLUGIN_ROOT}/config/agent.Rprofile" }
# R reads R_PROFILE_USER *instead of* ~/.Rprofile, so the user's profile is
# sourced explicitly below. languageserver's callr children source this file
# too, which is what carries the lintr.linter_file option into the subprocess
# where linting actually runs — but callr rewrites the R_PROFILE_USER env var
# to its own chained profile in those children, so this file must not locate
# itself through R_PROFILE_USER there (see self-location below).
# This file must never write to stdout: output would corrupt the LSP stream.

local({
  user_profile <- path.expand("~/.Rprofile")
  if (file.exists(user_profile)) {
    # ~/.Rprofile may cat()/print(); on the LSP's stdio channel that is protocol
    # corruption. Discard R-level stdout while it runs. Only base and methods are
    # attached this early, so utils::capture.output does not exist yet — sink(),
    # nullfile() and file() are base. A subprocess started by the profile still
    # writes fd 1 directly; sink() cannot reach that.
    # finally, not error: a profile that throws already halts every other R
    # session the user runs, and continuing on half-applied .libPaths() would
    # give languageserver a broken library set and the agent bogus diagnostics.
    null_con <- file(nullfile(), open = "wt")
    sink(null_con)
    tryCatch(source(user_profile), finally = {
      sink()
      close(null_con)
    })
  }

  # Self-location: CLAUDE_PLUGIN_ROOT is exported by Claude Code to the server
  # process and inherited unchanged by callr children; R_PROFILE_USER is the
  # fallback for non-Claude launches (tests, manual runs), where only the main
  # process sees the true path.
  plugin_root <- Sys.getenv("CLAUDE_PLUGIN_ROOT")
  if (nzchar(plugin_root) && dir.exists(file.path(plugin_root, "config"))) {
    config_dir <- file.path(plugin_root, "config")
  } else {
    self <- Sys.getenv("R_PROFILE_USER")
    if (!nzchar(self) || !file.exists(self)) {
      return(invisible())
    }
    config_dir <- dirname(self)
  }

  # A project's own lintr config always wins: only point lintr at the agent
  # profile when no .lintr/.lintr.R exists anywhere up the directory tree.
  # (options(lintr.linter_file=) with an absolute path would otherwise
  # override the project config — the agent must not see fewer lints than CI.)
  has_project_lintr <- function() {
    dir <- getwd()
    repeat {
      candidates <- file.path(dir, c(".lintr", ".lintr.R"))
      if (any(file.exists(candidates))) {
        return(TRUE)
      }
      parent <- dirname(dir)
      if (identical(parent, dir)) {
        return(FALSE)
      }
      dir <- parent
    }
  }
  agent_lintr <- file.path(config_dir, "agent.lintr")
  if (!has_project_lintr() && file.exists(agent_lintr)) {
    options(lintr.linter_file = agent_lintr)
  }

  # Formatting belongs to the air hook: languageserver's styler formatting is
  # synchronous (blocks the whole event loop) and would fight air. These keys
  # are applied at initialize time, so options() is the only channel for them.
  options(
    languageserver.server_capabilities = list(
      documentFormattingProvider = FALSE,
      documentRangeFormattingProvider = FALSE,
      documentOnTypeFormattingProvider = FALSE
    )
  )
})
