-- Plugin: mrcjkb/rustaceanvim
return function(ctx)
  local load_plugin = ctx.load_plugin
  local load_plugins = ctx.load_plugins
  local lsp_merge_project_config = ctx.lsp_merge_project_config
  local kind_icons_list = ctx.kind_icons_list
  local kind_icons = ctx.kind_icons
  local highlight_group_list = ctx.highlight_group_list
  local icons = ctx.icons
  local highlights = ctx.highlights
  local vscode_next_hunk = ctx.vscode_next_hunk
  local vscode_prev_hunk = ctx.vscode_prev_hunk

  return {

    {
      "mrcjkb/rustaceanvim",
      dependencies = "nvim-lspconfig",
      config = function()
        vim.g.rustaceanvim = function()
          local extension_path = vim.fn.stdpath("data") .. "/mason/"
          local codelldb_path = extension_path .. "bin/codelldb"
          local liblldb_path = extension_path .. "packages/codelldb/extension/lldb/lib/liblldb.so"

          local lsp_config = get_lsp_common_config()
          lsp_config.capabilities.offsetEncoding = nil

          local cfg = require("rustaceanvim.config")
          return {
            server = lsp_merge_project_config(lsp_config),
            dap = {
              adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
            },
          }
        end
        vim.api.nvim_buf_create_user_command(0, "RustLspExpandMacro", function()
          vim.cmd.RustLsp("expandMacro")
        end, {})
      end,
    },

  }
end
