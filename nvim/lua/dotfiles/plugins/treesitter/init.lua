local M = {}

local modules = {
  require("dotfiles.plugins.treesitter.nvim_treesitter"),
  require("dotfiles.plugins.treesitter.playground"),
  require("dotfiles.plugins.treesitter.nvim_treesitter_textobjects"),
  require("dotfiles.plugins.treesitter.nvim_treesitter_context"),
  require("dotfiles.plugins.treesitter.nvim_ts_autotag"),
  require("dotfiles.plugins.treesitter.hlargs"),
  require("dotfiles.plugins.treesitter.rainbow_delimiters"),
  require("dotfiles.plugins.treesitter.vim_illuminate"),
  require("dotfiles.plugins.treesitter.vim_matchup"),
  require("dotfiles.plugins.treesitter.rainbow"),
  require("dotfiles.plugins.treesitter.nvim_ufo"),
  require("dotfiles.plugins.treesitter.treesj"),
  require("dotfiles.plugins.treesitter.indent_blankline"),
}

function M.setup(ctx)
  local specs = {}
  for _, mod in ipairs(modules) do
    local entries = mod(ctx)
    if entries ~= nil then
      for _, spec in ipairs(entries) do
        table.insert(specs, spec)
      end
    end
  end
  return specs
end

return M
