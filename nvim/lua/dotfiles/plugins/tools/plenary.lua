-- Plugin: nvim-lua/plenary.nvim
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
      "nvim-lua/plenary.nvim",
      cmd = {
        "PlenaryProfile",
        "PlenaryProfileStop",
      },
      config = function()
        vim.api.nvim_create_user_command("PlenaryProfile", function()
          require("plenary.profile").start("profile.log", { flame = true })
        end, { nargs = 0 })
        vim.api.nvim_create_user_command("PlenaryProfileStop", function()
          require("plenary.profile").stop()
        end, { nargs = 0 })
      end,
    },

  }
end
