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
      "olimorris/codecompanion.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      cmd = {
        "CodeCompanion",
        "CodeCompanionChat",
        "CodeCompanionActions",
        "CodeCompanionCmd",
      },
      config = function()
        local copilot_adapter = {
          name = "copilot",
          model = "claude-sonnet-4.5",
        }
        local opts = {
          adapters = {
            acp = {
              codex = function()
                return require("codecompanion.adapters").extend("codex", {
                  defaults = {
                    auth_method = "chatgpt",
                  },
                })
              end,
            },
          },
          display = {
            chat = {
              window = {
                position = "right",
                width = 0.4,
              },
            },
          },
          interactions = {
            background = {
              adapter = copilot_adapter,
            },
            chat = {
              adapter = "codex",
            },
            -- chat = {
            --   adapter = copilot_adapter,
            -- },
            inline = {
              adapter = copilot_adapter,
            },
            cmd = {
              adapter = copilot_adapter,
            },
          },
        }
        require("codecompanion").setup(opts)
      end
    },

  }
end
