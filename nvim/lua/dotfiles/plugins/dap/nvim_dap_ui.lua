-- Plugin: rcarriga/nvim-dap-ui
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
      "rcarriga/nvim-dap-ui",
      dependencies = {
        "nvim-neotest/nvim-nio",
      },
      config = function()
        local dapui = require("dapui")
        dapui.setup({
          mappings = {
            -- Use a table to apply multiple mappings
            expand = { "<CR>", "<2-LeftMouse>" },
            open = "o",
            remove = "d",
            edit = "e",
            repl = "r",
          },
          layouts = {
            {
              elements = {
                -- Elements can be strings or table with id and size keys.
                { id = "scopes", size = 0.25 },
                "breakpoints",
                "stacks",
                "watches",
              },
              size = 40, -- 40 columns
              position = "left",
            },
            {
              elements = {
                "repl",
                "console",
              },
              size = 0.25, -- 25% of total lines
              position = "bottom",
            },
          },
          controls = {
            enabled = true,
            element = "watches",
          },
          floating = {
            max_height = nil, -- These can be integers or a float between 0 and 1.
            max_width = nil, -- Floats will be treated as percentage of your screen.
            border = "single", -- Border style. Can be "single", "double" or "rounded"
            mappings = {
              close = { "q", "<Esc>" },
            },
          },
          windows = { indent = 1 },
        })

        local dap = require("dap")
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
          dapui.close()
        end

        -- Highlight
        vim.cmd([[
          hi! link DapUIVariable Normal
          hi! link DapUIScope TextInfo
          hi! link DapUIType Function
          hi! link DapUIValue Normal
          hi! link DapUIModifiedValue BoldInfo
          hi! link DapUIDecoration DapUIScope
          hi! link DapUIThread TextSuccess
          hi! link DapUIStoppedThread DapUIScope
          hi! link DapUIFrameName Normal
          hi! link DapUISource Function
          hi! link DapUILineNumber DapUIScope
          hi! link DapUIFloatBorder DapUIScope
          hi! DapUIWatchesEmpty guifg=#F70067
          hi! link DapUIWatchesValue TextSuccess
          hi! DapUIWatchesError guifg=#F70067
          hi! link DapUIBreakpointsPath DapUIScope
          hi! link DapUIBreakpointsInfo TextSuccess
          hi! link DapUIBreakpointsCurrentLine BoldSuccess
          hi! link DapUIBreakpointsLine DapUILineNumber
          hi! DapUIBreakpointsDisabledLine guifg=#424242
        ]])
      end,
    },

  }
end
