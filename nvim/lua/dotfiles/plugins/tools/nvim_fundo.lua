-- Plugin: kevinhwang91/nvim-fundo
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
      -- permanent undo file
      "kevinhwang91/nvim-fundo",
      dependencies = { "kevinhwang91/promise-async" },
      keys = { "u", "<C-r>" },
      cond = vim.g.vscode == nil,
      build = function()
        require("fundo").install()
      end,
    },

  }
end
