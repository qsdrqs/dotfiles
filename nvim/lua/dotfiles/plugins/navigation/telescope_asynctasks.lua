-- Plugin: GustavoKatel/telescope-asynctasks.nvim
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
      "GustavoKatel/telescope-asynctasks.nvim",
      lazy = true,
      keys = { "<localleader>at", "<leader>ae" },
      cmd = "AsyncTaskTelescope",
      config = function()
        load_plugins({ "asynctasks.vim", "asyncrun.vim" })
        -- Fuzzy find over current tasks
        vim.cmd([[command! AsyncTaskTelescope lua require("telescope").extensions.asynctasks.all()]])
        vim.keymap.set("n", "<leader>at", "<cmd>AsyncTaskTelescope<cr>", { silent = true })
      end,
    },

  }
end
