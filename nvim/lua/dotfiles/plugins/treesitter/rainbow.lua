-- Plugin: luochen1990/rainbow
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
      "luochen1990/rainbow",
      lazy = true,
      config = function()
        -- same as vim rainbow
        vim.g.rainbow_active = 1
        vim.g.rainbow_conf = {
          guifgs = { "#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF" }, -- table of hex strings
        }
      end,
    },

  }
end
