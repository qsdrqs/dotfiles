-- Plugin: ldelossa/litee-calltree.nvim
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
      "ldelossa/litee-calltree.nvim",
      cmd = { "IncomingCalls", "OutgoingCalls" },
      dependencies = { "ldelossa/litee.nvim" },
      config = function()
        -- configure the litee.nvim library
        require("litee.lib").setup({})
        -- configure litee-calltree.nvim
        require("litee.calltree").setup({
          keymaps = {
            expand = "o",
            collapse = "O",
          },
        })
        vim.api.nvim_create_user_command("IncomingCalls", vim.lsp.buf.incoming_calls, { nargs = 0 })
        vim.api.nvim_create_user_command("OutgoingCalls", vim.lsp.buf.outgoing_calls, { nargs = 0 })
        vim.keymap.set("n", "<c-l>", "<cmd>LTClearJumpHL<cr><cmd>nohlsearch<cr>", { silent = true })
      end,
    },

  }
end
