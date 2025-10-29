-- Plugin: lukas-reineke/indent-blankline.nvim
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
      "lukas-reineke/indent-blankline.nvim",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        local ok, treesitter = pcall(require, "nvim-treesitter")
        if vim.b.treesitter_disable ~= 1 then
          vim.g.indent_blankline_show_current_context = true
          vim.g.indent_blankline_show_current_context_start = true
        end
        local hooks = require("ibl.hooks")
        require("ibl").setup({
          indent = {
            -- char = '▏',
            -- context_char = '▎',
          },
          debounce = 300,
          scope = {
            enabled = true,
            highlight = highlight_group_list,
            show_end = true,
          },
        })
        hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
      end,
    },

  }
end
