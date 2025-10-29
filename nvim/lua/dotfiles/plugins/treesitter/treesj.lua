-- Plugin: Wansmer/treesj
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
      "Wansmer/treesj",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      keys = { { "<leader>j", mode = "n" } },
      config = function()
        require("treesj").setup({
          use_default_keymaps = false,
        })
        vim.keymap.set("n", "<leader>j", require("treesj").toggle, { silent = true })
      end,
    },

  }
end
