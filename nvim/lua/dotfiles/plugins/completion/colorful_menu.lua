-- Plugin: xzbdmw/colorful-menu.nvim
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
      "xzbdmw/colorful-menu.nvim",
      config = function()
        -- local function_hl = vim.api.nvim_get_hl(0, { name = "Function", link = false })
        -- function_hl.bold = false
        -- vim.api.nvim_set_hl(0, "FunctionNoBold", function_hl)
        require("colorful-menu").setup({
          fallback_highlight = "@variable",
          max_width = 60,
        })
      end,
    },

  }
end
