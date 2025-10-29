-- Plugin: mfussenegger/nvim-dap
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

  }
end
