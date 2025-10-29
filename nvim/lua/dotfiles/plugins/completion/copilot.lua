-- Plugin: zbirenbaum/copilot.lua
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
      "zbirenbaum/copilot.lua",
      lazy = true,
      init = function()
        vim.g.copilot_filetypes = {
          ["dap-repl"] = false,
          dapui_watches = false,
          markdown = true,
        }
      end,
      config = function()
        require("copilot").setup({
          panel = {
            keymap = {
              open = "<M-\\>",
            },
            layout = {
              position = "top", -- | top | left | right
              ratio = 0.4,
            },
          },
          suggestion = {
            auto_trigger = true,
            debounce = 75,
            keymap = {
              accept = nil,
              accept_word = false,
              accept_line = false,
              next = "<M-]>",
              prev = "<M-[>",
              dismiss = "<C-]>",
            },
          },
          filetypes = {
            ["dap-repl"] = false,
            dapui_watches = false,
            markdown = true,
          },
        })
        vim.g.copilot_echo_num_completions = 1
        vim.g.copilot_no_tab_map = true
        vim.g.copilot_assume_mapped = true
        vim.g.copilot_tab_fallback = ""
      end,
    },

  }
end
