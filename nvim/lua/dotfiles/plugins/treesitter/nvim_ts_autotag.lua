-- Plugin: windwp/nvim-ts-autotag
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
      "windwp/nvim-ts-autotag",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("nvim-treesitter.configs").setup({
          autotag = {
            enable = true,
          },
        })
      end,
    },

  }
end
