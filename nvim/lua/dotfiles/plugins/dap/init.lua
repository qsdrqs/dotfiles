local M = {}

function M.setup(ctx)
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

  local specs = {
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        "rcarriga/nvim-dap-ui",
        "theHamsta/nvim-dap-virtual-text",
        "mfussenegger/nvim-dap-python",
        "Weissle/persistent-breakpoints.nvim",
      },
      keys = {
        "<F5>",
        "<F9>",
      },
      init = function()
        vim.cmd("hi debugRed guifg=red")
        vim.fn.sign_define("DapBreakpoint", { text = "🛑", texthl = "debugRed", linehl = "", numhl = "" })
      end,
      config = function()
        local function term_dap()
          require("dapui").close()
          require("nvim-dap-virtual-text/virtual_text").clear_virtual_text()
        end

        local dap = require("dap")
        local persist_bp = require("persistent-breakpoints.api")
        dap.defaults.fallback.terminal_win_cmd = "vertical rightbelow 50new"
        vim.keymap.set("n", "<F2>", function()
          dap.terminate({}, { terminateDebuggee = true }, term_dap())
        end, { silent = true })
        vim.keymap.set("n", "<F5>", dap.continue, { silent = true })
        vim.keymap.set("n", "<leader><F5>", dap.run_to_cursor, { silent = true })
        vim.keymap.set("n", "<F6>", dap.pause, { silent = true })
        vim.keymap.set("n", "<F6>", dap.pause, { silent = true })
        vim.keymap.set("n", "<F10>", dap.step_over, { silent = true })
        vim.keymap.set("n", "<F11>", dap.step_into, { silent = true })
        vim.keymap.set("n", "<F12>", dap.step_out, { silent = true })
        vim.keymap.set("n", "<F9>", persist_bp.toggle_breakpoint, { silent = true })
        vim.keymap.set("n", "<leader><F9>", persist_bp.clear_all_breakpoints, { silent = true })
        vim.keymap.set("n", "<F7>", require("dapui").eval, { silent = true })
        vim.keymap.set("v", "<F7>", require("dapui").eval, { silent = true })

        ---------------------------temp solution------------------------------------------------------
        -- TODO: remove this after
        local function toggle_bp(c, h, l, r)
          require("dap.breakpoints").toggle({
            condition = c,
            hit_condition = h,
            log_message = l,
            replace = r,
          })
        end
        dap.toggle_breakpoint = toggle_bp
        ----------------------------------------------------------------------------------------------

        -- C/C++
        dap.adapters.cppdbg = {
          id = "cppdbg",
          type = "executable",
          command = "OpenDebugAD7",
        }

        --[[ dap.adapters.codelldb = function(callback, config)
        -- specify in your configuration host = your_host , port = your_port
        callback({ type = "server", host = config.host, port = config.port })
        end ]]

        dap.adapters.lldb = {
          type = "server",
          port = "${port}",
          executable = {
            -- CHANGE THIS to your path!
            command = "codelldb",
            args = { "--port", "${port}" },

            -- On windows you may have to uncomment this:
            -- detached = false,
          },
        }

        dap.configurations.cuda = {
          {
            name = "Launch file",
            type = "cppdbg",
            -- type = "lldb",
            request = "launch",
            miDebuggerPath = "/opt/cuda/bin/cuda-gdb",
            -- stopOnEntry = true,
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
            end,
            externalConsole = false,
            -- program = "./${fileBasenameNoExtension}",
            cwd = "${workspaceFolder}",
            setupCommands = {
              {
                text = "-enable-pretty-printing",
                description = "enable pretty printing",
                ignoreFailures = false,
              },
            },
          },
        }
        dap.configurations.cpp = {
          {
            name = "Launch file",
            type = "cppdbg",
            -- type = "lldb",
            request = "launch",
            -- stopOnEntry = true,
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
            end,
            externalConsole = false,
            -- program = "./${fileBasenameNoExtension}",
            cwd = "${workspaceFolder}",
            setupCommands = {
              {
                text = "-enable-pretty-printing",
                description = "enable pretty printing",
                ignoreFailures = false,
              },
              {
                description = "Set Disassembly Flavor to Intel",
                text = "-gdb-set disassembly-flavor intel",
                ignoreFailures = true,
              },
            },
          },
          {
            name = "Attach file",
            type = "cppdbg",
            -- type = "lldb",
            request = "attach",
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
            end,
            -- program = "./${fileBasenameNoExtension}",
            MIMode = "gdb",
            processId = function()
              return vim.fn.input("procsesID: ")
            end,
            cwd = "${workspaceFolder}",
            setupCommands = {
              {
                text = "-enable-pretty-printing",
                description = "enable pretty printing",
                ignoreFailures = false,
              },
            },
          },
        }
        dap.configurations.c = dap.configurations.cpp
        dap.configurations.rust = dap.configurations.cpp
        dap.configurations.asm = dap.configurations.cpp
        vim.api.nvim_create_user_command("DapGDBMemory", function(opts)
          local fargs = opts.fargs
          local tmpfile = vim.fn.tempname()
          print(tmpfile)
          local address = fargs[1] or vim.fn.input("Address: ")
          local size = fargs[2] or 1000
          local cmd = string.format("-exec dump binary memory %s %s %s", tmpfile, address, address .. "+" .. size)
          dap.repl.execute(cmd)
          vim.defer_fn(function()
            vim.cmd("e " .. tmpfile)
            vim.cmd("%!xxd")
          end, 0)
        end, { nargs = "*" })
        vim.api.nvim_create_user_command("DapListBreakpoints", dap.list_breakpoints, { nargs = 0 })

        -- jump between breakpoints
        local function jump_breakpoints(up)
          local bufnr = vim.api.nvim_get_current_buf()
          local bps = require("dap.breakpoints").get()[bufnr]
          if bps == nil or #bps == 0 then
            vim.api.nvim_echo({ { "No breakpoints", "WarningMsg" } }, false, {})
            return
          end
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local nearest = nil
          for _, bp in ipairs(bps) do
            if up then
              if bp.line < lnum then
                nearest = bp
              else
                break
              end
            else
              if bp.line > lnum then
                nearest = bp
                break
              end
            end
          end
          if nearest then
            vim.api.nvim_win_set_cursor(0, { nearest.line, 0 })
            return
          end
          if up then
            vim.api.nvim_win_set_cursor(0, { bps[#bps].line, 0 })
          else
            vim.api.nvim_win_set_cursor(0, { bps[1].line, 0 })
          end
        end
        vim.keymap.set("n", "]b", function()
          jump_breakpoints(false)
        end, { silent = true })
        vim.keymap.set("n", "[b", function()
          jump_breakpoints(true)
        end, { silent = true })

        -- Java use nvim-jdtls
        -- Python use nvim-dap-python

        -- Go
        dap.adapters.go = {
          type = "server",
          port = "${port}",
          executable = {
            command = "dlv",
            args = { "dap", "-l", "127.0.0.1:${port}" },
          },
        }

        -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
        dap.configurations.go = {
          {
            type = "go",
            name = "Debug",
            request = "launch",
            program = "${file}",
          },
          {
            type = "go",
            name = "Debug test", -- configuration for debugging test files
            request = "launch",
            mode = "test",
            program = "${file}",
          },
          -- works with go.mod packages and sub packages
          {
            type = "go",
            name = "Debug test (go.mod)",
            request = "launch",
            mode = "test",
            program = "./${relativeFileDirname}",
          },
        }

        -- Dap load launch.json from vscode when avaliable
        vim.api.nvim_create_autocmd("DirChanged", {
          pattern = "*",
          callback = function()
            if vim.fn.filereadable("./.vscode/launch.json") then
              require("dap.ext.vscode").load_launchjs(nil, { cppdbg = { "c", "cpp", "asm" }, lldb = { "rust" } })
            end
          end,
        })
        if vim.fn.filereadable("./.vscode/launch.json") then
          require("dap.ext.vscode").load_launchjs(nil, { cppdbg = { "c", "cpp", "asm" }, lldb = { "rust" } })
        end
      end,
    },

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

    {
      "theHamsta/nvim-dap-virtual-text",
      config = function()
        require("nvim-dap-virtual-text").setup({
          enabled = true, -- enable this plugin (the default)
          enabled_commands = true, -- create commands DapVirtualTextEnable, DapVirtualTextDisable, DapVirtualTextToggle, (DapVirtualTextForceRefresh for refreshing when debug adapter did not notify its termination)
          highlight_changed_variables = true, -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
          highlight_new_as_changed = false, -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
          show_stop_reason = true, -- show stop reason when stopped for exceptions
          commented = false, -- prefix virtual text with comment string
          -- experimental features:
          virt_text_pos = "eol", -- position of virtual text, see `:h nvim_buf_set_extmark()`
          all_frames = false, -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
          virt_lines = false, -- show virtual lines instead of virtual text (will flicker!)
          virt_text_win_col = nil, -- position the virtual text at a fixed window column (starting from the first text column) ,
          -- e.g. 80 to position at column 80, see `:h nvim_buf_set_extmark()`
        })
      end,
    },

    {
      "Weissle/persistent-breakpoints.nvim",
      config = function()
        require("persistent-breakpoints").setup({
          load_breakpoints_event = { "BufReadPost" },
        })
      end,
    },
  }

  return specs
end

return M
