-- Plugin: folke/sidekick.nvim
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
      "folke/sidekick.nvim",
      dependencies = {
        "zbirenbaum/copilot.lua",
      },
      cond = vim.g.vscode == nil,
      opts = {
        -- add any options here
        cli = {
          mux = {
            backend = "tmux",
            enabled = true,
          },
          prompts = {
            commit = "Based on the current changes in this Git repository and the commit history, generate a descriptive git commit message that matches the style of previous commits.",
          },
        },
      },
      keys = {
        {
          "<tab>",
          function()
            -- if there is a next edit, jump to it, otherwise apply it if any
            if not require("sidekick").nes_jump_or_apply() then
              return "<Tab>" -- fallback to normal tab
            end
          end,
          expr = true,
          desc = "Goto/Apply Next Edit Suggestion",
        },
        -- {
        --   "<c-.>",
        --   function()
        --     require("sidekick.cli").toggle()
        --   end,
        --   desc = "Sidekick Toggle",
        --   mode = { "n", "t", "i", "x" },
        -- },
        -- {
        --   "<localleader>aa",
        --   function()
        --     require("sidekick.cli").send({ msg = "{file}" })
        --   end,
        --   desc = "Send File",
        --   mode = { "n", "t" },
        -- },
        -- {
        --   "<localleader>as",
        --   function()
        --     require("sidekick.cli").select({ filter = { installed = true } })
        --   end,
        --   desc = "Select CLI",
        -- },
        -- {
        --   "<localleader>ad",
        --   function()
        --     require("sidekick.cli").close()
        --   end,
        --   desc = "Detach a CLI Session",
        -- },
        -- {
        --   "<localleader>aa",
        --   function()
        --     require("sidekick.cli").send({ msg = "{this}" })
        --   end,
        --   mode = { "x" },
        --   desc = "Send This",
        -- },
        -- {
        --   "<localleader>av",
        --   function()
        --     require("sidekick.cli").send({ msg = "{selection}" })
        --   end,
        --   mode = { "x" },
        --   desc = "Send Visual Selection",
        -- },
        -- {
        --   "<localleader>ap",
        --   function()
        --     require("sidekick.cli").prompt()
        --   end,
        --   mode = { "n", "x" },
        --   desc = "Sidekick Select Prompt",
        -- },
        -- -- Example of a keybinding to open codex directly
        -- {
        --   "<localleader>ac",
        --   function()
        --     require("sidekick.cli").toggle({ name = "codex", focus = true })
        --   end,
        --   desc = "Sidekick Toggle Codex",
        -- },
      },
    },

  }
end
