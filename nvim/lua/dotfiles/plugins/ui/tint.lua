-- Plugin: levouh/tint.nvim
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
      "levouh/tint.nvim",
      lazy = false,
      cond = vim.g.vscode == nil,
      config = function()
        require("tint").setup({
          tint = -45, -- Darken colors, use a positive value to brighten
          saturation = 0.6, -- Saturation to preserve
        })
        vim.api.nvim_create_user_command("TintToggle", require("tint").toggle, { nargs = 0 })
      end,
    },

  }
end
