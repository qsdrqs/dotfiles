-- Plugin: ray-x/lsp_signature.nvim
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
      "ray-x/lsp_signature.nvim",
      config = function()
        require("lsp_signature").setup({
          bind = true, -- This is mandatory, otherwise border config won't get registered.
          floating_window = true,
          floating_window_above_cur_line = true,
          handler_opts = {
            border = "rounded",
          },
          hint_enable = false,
          transparency = 15,
          floating_window_off_x = function()
            local colnr = vim.api.nvim_win_get_cursor(0)[2] -- bu col number
            return colnr
          end,
          max_width = 40,
        })
      end,
    },

  }
end
