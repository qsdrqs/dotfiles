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
        "folke/snacks.nvim",
      },
      cond = vim.g.vscode == nil,
      init = function()
        vim.o.autoread = true
      end,
      opts = {
        -- add any options here
        cli = {
          tools = {
            opencode2 = {
              cmd = { "opencode2" },
              is_proc = "\\<opencode2\\>",
              native_scroll = true,
            },
          },
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
        {
          "<localleader>aa",
          function()
            require("sidekick.cli").send({ name = "opencode2", msg = "{this}", focus = true })
          end,
          mode = { "n", "x" },
          desc = "Send context to OpenCode2",
        },
        {
          "<localleader>as",
          function()
            require("sidekick.cli").prompt({
              cb = function(_, text)
                if text then
                  require("sidekick.cli").send({ name = "opencode2", text = text })
                end
              end,
            })
          end,
          mode = { "n", "x" },
          desc = "Select OpenCode2 prompt",
        },
        {
          "<localleader>at",
          function()
            require("sidekick.cli").toggle({ name = "opencode2" })
          end,
          mode = { "n", "t" },
          desc = "Toggle OpenCode2",
        },
        {
          "go",
          function()
            require("sidekick.cli").send({ name = "opencode2", msg = "{selection}", focus = true })
          end,
          mode = "x",
          desc = "Add selection to OpenCode2",
        },
        {
          "goo",
          function()
            require("sidekick.cli").send({ name = "opencode2", msg = "{line}", focus = true })
          end,
          mode = "n",
          desc = "Add line to OpenCode2",
        },
      },
    },
  }
end
