local M = {}

local modules = {
  require("dotfiles.plugins.tools.plenary"),
  require("dotfiles.plugins.tools.nvim_autopairs"),
  require("dotfiles.plugins.tools.flatten"),
  require("dotfiles.plugins.tools.toggleterm"),
  require("dotfiles.plugins.tools.direnv"),
  require("dotfiles.plugins.tools.nvim_fundo"),
  require("dotfiles.plugins.tools.vim_sandwich"),
  require("dotfiles.plugins.tools.vim_log_highlighting"),
  require("dotfiles.plugins.tools.sigsegvim"),
  require("dotfiles.plugins.tools.asynctasks"),
  require("dotfiles.plugins.tools.asyncrun"),
  require("dotfiles.plugins.tools.promise_async"),
  require("dotfiles.plugins.tools.v_coolor"),
  require("dotfiles.plugins.tools.bufdelete"),
  require("dotfiles.plugins.tools.vim_visual_multi"),
  require("dotfiles.plugins.tools.suda"),
  require("dotfiles.plugins.tools.undotree"),
  require("dotfiles.plugins.tools.align"),
  require("dotfiles.plugins.tools.dial"),
  require("dotfiles.plugins.tools.comment"),
  require("dotfiles.plugins.tools.rnvimr"),
  require("dotfiles.plugins.tools.vim_textobj_entire"),
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
