-- Plugin: skywind3000/asynctasks.vim
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
      "skywind3000/asynctasks.vim",
      lazy = true,
      dependencies = { "skywind3000/asyncrun.vim" },
      config = function()
        vim.g.asyncrun_open = 6
        vim.g.asynctasks_term_pos = "bottom"
        vim.g.asynctasks_term_rows = 14
        vim.keymap.set("n", "<leader>ae", "<cmd>AsyncTaskEdit<cr>", { silent = true })
      end,
    },

  }
end
