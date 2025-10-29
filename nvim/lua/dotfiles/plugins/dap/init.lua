local M = {}

local modules = {
  require("dotfiles.plugins.dap.nvim_dap"),
  require("dotfiles.plugins.dap.nvim_dap_python"),
  require("dotfiles.plugins.dap.nvim_dap_ui"),
  require("dotfiles.plugins.dap.nvim_dap_virtual_text"),
  require("dotfiles.plugins.dap.persistent_breakpoints"),
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
