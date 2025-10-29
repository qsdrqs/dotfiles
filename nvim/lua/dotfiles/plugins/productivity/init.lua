local M = {}

local modules = {
  require("dotfiles.plugins.productivity.auto_save"),
  require("dotfiles.plugins.productivity.markdown_preview"),
  require("dotfiles.plugins.productivity.vim_interestingwords"),
  require("dotfiles.plugins.productivity.vim_sleuth"),
  require("dotfiles.plugins.productivity.pantran"),
  require("dotfiles.plugins.productivity.venv_selector"),
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
