-- Plugin: kosayoda/nvim-lightbulb
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
      -- for code actions
      "kosayoda/nvim-lightbulb",
      config = function()
        local lightbulb = require("nvim-lightbulb")
        lightbulb.setup({
          autocmd = {
            enabled = true,
          },
          sign = {
            enabled = true,
            -- Text to show in the sign column.
            -- Must be between 1-2 characters.
            text = "💡",
            -- Highlight group to highlight the sign column text.
            hl = "LightBulbSign",
          },
          ignore = {
            clients = { "null-ls" },
          },
        })
      end,
    },

  }
end
