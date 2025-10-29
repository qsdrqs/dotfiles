local M = {}

local modules = {
  require("dotfiles.plugins.tags.cscope_maps"),
  require("dotfiles.plugins.tags.vim_gutentags"),
  require("dotfiles.plugins.tags.gutentags_plus"),
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
