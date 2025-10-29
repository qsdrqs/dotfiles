-- Plugin: smoka7/hop.nvim
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
      "smoka7/hop.nvim",
      lazy = true,
      keys = {
        { "<leader>w", mode = { "n", "v" } },
        { "<leader>l", mode = { "n", "v" } },
      },
      config = function()
        require("hop").setup()
        vim.keymap.set("n", "<leader>w", "<cmd>lua require'hop'.hint_words()<cr>", {})
        vim.keymap.set("v", "<leader>w", "<cmd>lua require'hop'.hint_words()<cr>", {})
        -- vim.keymap.set('n', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
        -- vim.keymap.set('v', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
        vim.keymap.set("n", "<leader>l", "<cmd>lua require'hop'.hint_lines()<cr>", {})
        vim.keymap.set("v", "<leader>l", "<cmd>lua require'hop'.hint_lines()<cr>", {})
      end,
    },

  }
end
