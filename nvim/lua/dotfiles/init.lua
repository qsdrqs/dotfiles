local bootstrap = require("dotfiles.core.bootstrap")
local helpers = require("dotfiles.core.helpers")
local icons = require("dotfiles.core.icons")
local highlights = require("dotfiles.core.highlights")
local autocmds = require("dotfiles.core.autocmds")
local state = require("dotfiles.core.state")
local runtime = require("dotfiles.core.runtime")

local M = {}

---Bootstrap lazy.nvim and expose shared resources.
--@param opts table? forwarded to bootstrap.ensure_lazy
--@return table context { use_nix, helpers, icons, highlights }
function M.setup(opts)
  local _, use_nix = bootstrap.ensure_lazy(opts)
  state.ensure_defaults()

  return {
    use_nix = use_nix,
    helpers = helpers,
    icons = icons,
    highlights = highlights,
    autocmds = autocmds,
    state = state,
    runtime = runtime,
  }
end

---Convenience accessors until the full migration lands.
M.helpers = helpers
M.icons = icons
M.highlights = highlights
M.autocmds = autocmds
M.state = state
M.runtime = runtime

function M.apply_highlights()
  highlights.apply_semantic_links()
end

function M.setup_autocmds()
  autocmds.setup()
end

function M.ensure_state()
  state.ensure_defaults()
end

function M.setup_runtime()
  runtime.setup()
end

return M
