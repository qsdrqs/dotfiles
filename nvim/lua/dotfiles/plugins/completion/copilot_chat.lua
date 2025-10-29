-- Plugin: CopilotC-Nvim/CopilotChat.nvim
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
      "CopilotC-Nvim/CopilotChat.nvim",
      dependencies = {
        "zbirenbaum/copilot.lua",
        "nvim-lua/plenary.nvim",
      },
      cmd = {
        "CopilotChat",
        "CopilotChatModel",
        "CopilotChatModels",
        "CopilotChatToggle",
        "CopilotChatExplain",
        "CopilotChatTests",
        "CopilotChatFixDiagnostic",
        "CopilotChatCommit",
        "CopilotChatCommitStaged",
      },
      config = function()
        require("CopilotChat").setup({
          debug = false, -- Enable or disable debug mode, the log file will be in ~/.local/state/nvim/CopilotChat.nvim.log
          context = "buffer",
          window = {
            layout = "vertical",
            width = 0.3,
          },
          mappings = {
            reset = {
              normal = "<C-S-L>",
              insert = "<C-l>",
            },
          },
        })
      end,
    },

  }
end
