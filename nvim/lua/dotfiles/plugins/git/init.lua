local M = {}

local modules = {
  require("dotfiles.plugins.git.gitsigns"),
  require("dotfiles.plugins.git.git_conflict"),
  require("dotfiles.plugins.git.diffview"),
  require("dotfiles.plugins.git.mini_diff"),
  require("dotfiles.plugins.git.vim_fugitive"),
  require("dotfiles.plugins.git.vim_flog"),
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
