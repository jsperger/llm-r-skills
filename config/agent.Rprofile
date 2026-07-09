# Startup profile for agent LSP sessions. Delivered via the plugin's .lsp.json:
#   "env": { "R_PROFILE_USER": "${CLAUDE_PLUGIN_ROOT}/config/agent.Rprofile" }
# R reads R_PROFILE_USER *instead of* ~/.Rprofile, so the user's profile is
# sourced explicitly below. languageserver's callr children inherit
# R_PROFILE_USER and source this file too, which is what carries the
# lintr.linter_file option into the subprocess where linting actually runs.
# This file must never write to stdout: output would corrupt the LSP stream.

local({
  user_profile <- path.expand("~/.Rprofile")
  if (file.exists(user_profile)) {
    source(user_profile)
  }

  self <- Sys.getenv("R_PROFILE_USER")
  if (!nzchar(self) || !file.exists(self)) {
    return(invisible())
  }
  config_dir <- dirname(self)

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
