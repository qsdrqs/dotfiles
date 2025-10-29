-- Plugin: lfv89/vim-interestingwords
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
      "lfv89/vim-interestingwords",
      lazy = true,
      keys = "<leader>h",
      init = function()
        vim.g.interestingWordsDefaultMappings = 0
        vim.g.interestingWordsGUIColors = { "#8CCBEA", "#A4E57E", "#FFDB72", "#FF7272", "#FFB3FF", "#9999FF" }
      end,
      config = function()
        vim.keymap.set("n", "<leader>h", "<cmd>call InterestingWords('n')<cr>", { silent = true })
        vim.keymap.set("v", "<leader>h", "<cmd>call InterestingWords('v')<cr>", { silent = true })
        vim.keymap.set("n", "<leader>H", "<cmd>call UncolorAllWords()<cr>", { silent = true })
      end,
    },

  }
end
