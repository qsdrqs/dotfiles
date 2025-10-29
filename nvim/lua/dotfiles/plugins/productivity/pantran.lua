-- Plugin: qsdrqs/pantran.nvim
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
      "qsdrqs/pantran.nvim",
      cond = vim.g.vscode == nil,
      keys = { { "<leader>y", mode = { "n", "x" } } },
      config = function()
        local opts = { noremap = true, silent = true, expr = true }
        local pantran = require("pantran")
        vim.keymap.set("n", "<leader>y", pantran.motion_translate, opts)
        vim.keymap.set("n", "<leader>yy", function()
          return pantran.motion_translate() .. "_"
        end, opts)
        vim.keymap.set("x", "<leader>y", pantran.motion_translate, opts)

        require("pantran").setup({
          default_engine = "google",
          engines = {
            deepl = {
              default_target = "ZH",
              auth_key = "fb82d24e-df8e-e7f2-5db4-142818d50c12:fx",
            },
            google = {
              fallback = {
                default_target = "zh-CN",
              },
            },
          },
        })
      end,
    },

  }
end
