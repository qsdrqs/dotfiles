-- Plugin: willothy/flatten.nvim
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
      "willothy/flatten.nvim",
      lazy = false,
      config = function()
        local saved_terminal
        require("flatten").setup({
          window = {
            open = "alternate",
          },
          hooks = {
            pre_open = function()
              local term = require("toggleterm.terminal")
              local termid = term.get_focused_id()
              saved_terminal = term.get(termid)
            end,
            post_open = function(bufnr, winnr, ft, is_blocking)
              if saved_terminal then
                saved_terminal:shutdown()
              end
            end,
          },
        })
      end,
    },

  }
end
