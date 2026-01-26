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
        require("project").setup({
          silent_chdir = true,
          manual_mode = false,
          lsp = {
            enabled = true,
            use_pattern_matching = true,
            ignore = { "clangd" },
          },
          patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc", "pom.xml" },
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
