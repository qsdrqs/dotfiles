local M = {}

local modules = {
  require("dotfiles.plugins.lsp.mason"),
  require("dotfiles.plugins.lsp.nvim_jdtls"),
  require("dotfiles.plugins.lsp.rustaceanvim"),
  require("dotfiles.plugins.lsp.clangd_extensions"),
  require("dotfiles.plugins.lsp.actions_preview"),
  require("dotfiles.plugins.lsp.nvim_lspconfig"),
  require("dotfiles.plugins.lsp.none_ls"),
  require("dotfiles.plugins.lsp.none_ls_extras"),
  require("dotfiles.plugins.lsp.lsp_signature"),
  require("dotfiles.plugins.lsp.lsp_lines"),
  require("dotfiles.plugins.lsp.nvim_lightbulb"),
  require("dotfiles.plugins.lsp.fidget"),
  require("dotfiles.plugins.lsp.lazydev"),
  require("dotfiles.plugins.lsp.luvit_meta"),
  require("dotfiles.plugins.lsp.litee_calltree"),
  require("dotfiles.plugins.lsp.inc_rename"),
  require("dotfiles.plugins.lsp.trouble"),
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
