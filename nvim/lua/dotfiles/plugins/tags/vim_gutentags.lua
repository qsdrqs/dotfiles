-- Plugin: skywind3000/vim-gutentags
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
      --管理gtags，集中存放tags
      "skywind3000/vim-gutentags",
      lazy = true,
      init = function()
        vim.g.gutentags_define_advanced_commands = 1
      end,
      config = function()
        -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
        vim.g.gutentags_modules = { "ctags", "gtags_cscope", "cscope_maps" }

        -- config project root markers.
        vim.g.gutentags_project_root = { ".root", ".svn", ".git", ".hg", ".project", ".exrc", "pom.xml" }

        -- generate datebases in my cache directory, prevent gtags files polluting my project
        vim.g.gutentags_cache_dir = os.getenv("HOME") .. "/.cache/tags"

        -- change focus to quickfix window after search (optional).
        vim.g.gutentags_plus_switch = 1

        vim.g.gutentags_load = 1
      end,
    },

  }
end
