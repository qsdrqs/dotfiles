local M = {}

local modules = {
  require("dotfiles.plugins.ui.statuscol"),
  require("dotfiles.plugins.ui.nvim_colorizer"),
  require("dotfiles.plugins.ui.bufferline"),
  require("dotfiles.plugins.ui.aerial"),
  require("dotfiles.plugins.ui.dropbar"),
  require("dotfiles.plugins.ui.render_markdown"),
  require("dotfiles.plugins.ui.lualine"),
  require("dotfiles.plugins.ui.nvim_web_devicons"),
  require("dotfiles.plugins.ui.alpha_nvim"),
  require("dotfiles.plugins.ui.satellite"),
  require("dotfiles.plugins.ui.todo_comments"),
  require("dotfiles.plugins.ui.nvim_notify"),
  require("dotfiles.plugins.ui.dressing"),
  require("dotfiles.plugins.ui.tint"),
  require("dotfiles.plugins.ui.nvim_tree"),
  require("dotfiles.plugins.ui.firenvim"),
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
