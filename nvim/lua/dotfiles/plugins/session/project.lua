-- Plugin: DrKJeff16/project.nvim
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
      "DrKJeff16/project.nvim",
      config = function()
        vim.g.project_lsp_nowarn = 1
        require("project").setup({
          silent_chdir = true,
          manual_mode = false,
          patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc", "pom.xml" },
          detection_methods = { "pattern", "lsp" },
          ignore_lsp = { "clangd" },
          exclude_dirs = { "~" },
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        })

        require("telescope").load_extension("projects")
      end,
    },

  }
end
