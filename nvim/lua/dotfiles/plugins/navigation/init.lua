local M = {}

local modules = {
  require("dotfiles.plugins.navigation.telescope"),
  require("dotfiles.plugins.navigation.telescope_asynctasks"),
  require("dotfiles.plugins.navigation.fzf_lua"),
  require("dotfiles.plugins.navigation.cellular_automaton"),
  require("dotfiles.plugins.navigation.nvim_bqf"),
  require("dotfiles.plugins.navigation.nvim_hlslens"),
  require("dotfiles.plugins.navigation.hop"),
  require("dotfiles.plugins.navigation.flash"),
  require("dotfiles.plugins.navigation.which_key"),
  require("dotfiles.plugins.navigation.marks"),
  require("dotfiles.plugins.navigation.registers"),
  require("dotfiles.plugins.navigation.yazi"),
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
