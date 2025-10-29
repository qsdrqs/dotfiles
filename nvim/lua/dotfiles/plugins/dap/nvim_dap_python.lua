-- Plugin: mfussenegger/nvim-dap-python
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
      "mfussenegger/nvim-dap-python",
      config = function()
        local dap_python = require("dap-python")
        dap_python.setup()
        vim.api.nvim_create_user_command("DebugpyTestMethod", function()
          dap_python.test_method()
        end, { nargs = 0 })
        vim.api.nvim_create_user_command("DebugpyTestClass", function()
          dap_python.test_class()
        end, { nargs = 0 })
        vim.api.nvim_create_user_command("DebugpyDebugSelection", function()
          dap_python.debug_selection()
        end, { nargs = 0 })
      end,
    },

  }
end
