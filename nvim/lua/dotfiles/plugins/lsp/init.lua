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
      "williamboman/mason.nvim",
      lazy = true,
      cmd = "Mason",
      init = function()
        vim.fn.setenv("PATH", vim.fn.getenv("PATH") .. ":" .. vim.fn.stdpath("data") .. "/mason/bin")
      end,
      config = function()
        require("mason").setup()
      end,
    },

    {
      "mfussenegger/nvim-jdtls",
      dependencies = "nvim-lspconfig",
      config = function()
        -- java
        local jdt_config = get_lsp_common_config()
        local java_exec
        if vim.fn.filereadable("/run/current-system/sw/bin/java") then
          java_exec = "/run/current-system/sw/bin/java"
        else
          java_exec = "java"
        end
        jdt_config.cmd = {
          vim.fn.stdpath("data") .. "/mason/bin/jdtls",
          "--java-executable=" .. java_exec,
        }

        -- 💀
        -- This is the default if not provided, you can remove it. Or adjust as needed.
        -- One dedicated LSP server & client will be started per unique root_dir
        jdt_config.root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", ".classpath", ".exrc" })

        -- Here you can configure eclipse.jdt.ls specific settings
        -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        -- for a list of options
        jdt_config.settings = {
          java = {
            completion = {
              overwrite = true,
              guessMethodArguments = true,
            },
            selectionRange = {
              enabled = true,
            },
            inlayHints = {
              parameterNames = {
                enabled = "all",
              },
            },
            implementationsCodeLens = true,
            referencesCodeLens = true,
          },
        }

        jdt_config.name = "jdtls"

        -- progress_report
        jdt_config.handlers = {
          -- disable default progress report
          ["language/status"] = function() end,
        }

        -- Language server `initializationOptions`
        -- You need to extend the `bundles` with paths to jar files
        -- if you want to use additional eclipse.jdt.ls plugins.
        --
        -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
        --
        -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
        local bundles = {
          vim.fn.glob(
            vim.fn.stdpath("data")
              .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
          ),
        }
        vim.list_extend(
          bundles,
          vim.split(vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/java-test/extension/server/*.jar"), "\n")
        )
        jdt_config.init_options = {
          bundles = bundles,
        }

        vim.api.nvim_create_user_command("JdtDebugTestClass", "lua require('jdtls').test_class()", { nargs = 0 })
        vim.api.nvim_create_user_command(
          "JdtDebugTestMethod",
          "lua require('jdtls').test_nearest_method()",
          { nargs = 0 }
        )

        jdt_config.on_attach = function(client, bufnr)
          -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
          -- you make during a debug session immediately.
          -- Remove the option if you do not want that.
          require("jdtls").setup_dap({ hotcodereplace = "auto" })
          common_on_attach(client, bufnr)
          require("jdtls.dap").setup_dap_main_class_configs()
        end

        local jdt_config = lsp_merge_project_config(jdt_config)

        -- jdtls needs to be started by FileType, and executed every time for each java file
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "java",
          callback = function()
            require("jdtls").start_or_attach(jdt_config)
          end,
        })
      end,
    },

    {
      "mrcjkb/rustaceanvim",
      dependencies = "nvim-lspconfig",
      config = function()
        vim.g.rustaceanvim = function()
          local extension_path = vim.fn.stdpath("data") .. "/mason/"
          local codelldb_path = extension_path .. "bin/codelldb"
          local liblldb_path = extension_path .. "packages/codelldb/extension/lldb/lib/liblldb.so"

          local lsp_config = get_lsp_common_config()
          lsp_config.capabilities.offsetEncoding = nil

          local cfg = require("rustaceanvim.config")
          return {
            server = lsp_merge_project_config(lsp_config),
            dap = {
              adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
            },
          }
        end
        vim.api.nvim_buf_create_user_command(0, "RustLspExpandMacro", function()
          vim.cmd.RustLsp("expandMacro")
        end, {})
      end,
    },

    {
      "p00f/clangd_extensions.nvim",
      dependencies = "nvim-lspconfig",
    },

    {
      "aznhe21/actions-preview.nvim",
      dependencies = {
        "nvim-telescope/telescope.nvim",
      },
      keys = {
        { "<leader>ca", mode = { "v", "n" } },
      },
      config = function()
        require("actions-preview").setup({
          telescope = {
            sorting_strategy = "ascending",
            layout_strategy = "vertical",
            layout_config = {
              width = 0.8,
              height = 0.9,
              prompt_position = "top",
              preview_cutoff = 20,
              preview_height = function(_, _, max_lines)
                return max_lines - 15
              end,
            },
          },
        })
        vim.keymap.set({ "v", "n" }, "<leader>ca", require("actions-preview").code_actions)
      end,
    },

    {
      "neovim/nvim-lspconfig",
      config = function()
        -- vim.lsp.set_log_level('DEBUG')
        vim.lsp.set_log_level("OFF")

        function common_on_attach(client, bufnr)
          -- Enable completion triggered by <c-x><c-o>
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

          -- codelens
          vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufEnter" }, {
            pattern = "*",
            callback = function()
              vim.lsp.codelens.refresh()
            end,
          })
          -- refresh on start
          vim.lsp.codelens.refresh()

          -- rust_analyzer needs to be defered refresh
          if client.name == "rust_analyzer" then
            vim.defer_fn(function()
              vim.lsp.codelens.refresh()
            end, 500)
          end

          -- inlay hints
          vim.lsp.inlay_hint.enable()
        end

        local function showDocument()
          local clients = vim.lsp.get_clients()
          if next(clients) ~= nil then
            vim.lsp.buf.hover()
          elseif vim.o.filetype == "help" or vim.o.filetype == "vim" or vim.o.filetype == "lua" then
            vim.cmd("execute 'h '.expand('<cword>')")
          else
            vim.cmd("execute '!' . &keywordprg . ' ' . expand('<cword>')")
          end
        end

        local opts = { noremap = true, silent = true }

        -- Mappings.
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        -- vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gd", "<cmd>Trouble lsp_definitions<CR>", opts)
        -- vim.keymap.set('n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
        vim.keymap.set("n", "gr", "<cmd>Trouble lsp_references<CR>", opts)

        vim.keymap.set("n", "gi", "<cmd>Trouble lsp_implementations<cr>", opts)
        vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
        vim.keymap.set("n", "<space>aa", vim.lsp.buf.add_workspace_folder, opts)
        vim.keymap.set("n", "<space>ar", vim.lsp.buf.remove_workspace_folder, opts)
        vim.keymap.set("n", "<space>al", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
        vim.keymap.set("n", "<space>D", "<cmd>Trouble lsp_type_definitions<CR>", opts)
        -- vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "c", "cpp" },
          callback = function(args)
            vim.keymap.set(
              "n",
              "gh",
              "<cmd>ClangdSwitchSourceHeader <CR>",
              { buffer = true, silent = true, noremap = true }
            )
          end,
        })

        local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
        vim.diagnostic.config({
          virtual_text = false,
          virtual_lines = false,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = signs.Error,
              [vim.diagnostic.severity.WARN] = signs.Warn,
              [vim.diagnostic.severity.INFO] = signs.Info,
              [vim.diagnostic.severity.HINT] = signs.Hint,
            },
            numhl = {
              [vim.diagnostic.severity.ERROR] = "DiagnosticError",
              [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
              [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
              [vim.diagnostic.severity.HINT] = "DiagnosticHint",
            },
          },
        })
        local virtualLineEnabled = false

        local function changeDiagnostic()
          require("lsp_lines") -- lazy load lsp_lines
          if virtualLineEnabled == false then
            vim.diagnostic.config({
              virtual_text = false,
              virtual_lines = true,
            })
            virtualLineEnabled = true
          else
            vim.diagnostic.config({
              -- virtual_text = true,
              virtual_lines = false,
            })
            virtualLineEnabled = false
          end
        end

        function get_lsp_common_config()
          local capabilities = require("blink.cmp").get_lsp_capabilities()
          capabilities.textDocument.foldingRange = {
            dynamicRegistration = false,
            lineFoldingOnly = true,
          }
          local config = {
            on_attach = common_on_attach,
            capabilities = capabilities,
            flags = {
              debounce_text_changes = 150,
            },
            handlers = {
              ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
                signs = true,
                underline = true,
                update_in_insert = false,
              }),
            },
          }
          return config
        end

        -- 'rust_analyzer' are handled by rustaceanvim.
        local servers = {
          "texlab",
          "lua_ls",
          "vimls",
          "hls",
          "ts_ls",
          "cmake",
          "gopls",
          "bashls",
          "buf_ls",
          "nixd",
          "clangd",
        }

        -- add my magic python lsp
        local python_server_name = "pyright"
        local python_custom_config
        local python_commands
        local ok, pycfg = pcall(require, "dotfiles.private.magic_py_lsp")
        if ok and type(pycfg) == "table" and pycfg.config ~= nil then
          python_server_name = pycfg.name or python_server_name
          python_custom_config = pycfg.config
          python_commands = pycfg.commands
        end
        servers[#servers + 1] = python_server_name

        local python_settings_patch = {
          python = {
            analysis = {
              diagnosticSeverityOverrides = {
                -- reportGeneralTypeIssues = "warning"
              },
            },
          },
        }

        for _, lsp in ipairs(servers) do
          local lsp_common_config = get_lsp_common_config()
          if lsp == "ts_ls" then
            -- lsp_common_config.root_dir = require('lspconfig.util').root_pattern("*")
          end

          if lsp == python_server_name then
            if python_custom_config then
              lsp_common_config = vim.tbl_deep_extend("force", lsp_common_config, python_custom_config)
            end
            lsp_common_config.settings =
              vim.tbl_deep_extend("force", lsp_common_config.settings or {}, python_settings_patch)
          elseif lsp == "clangd" then
            lsp_common_config.cmd = {
              "clangd",
              "--header-insertion-decorators=0",
              "-header-insertion=never",
              "--background-index",
            }
            lsp_common_config.filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }
            -- set offset encoding
            lsp_common_config.capabilities.offsetEncoding = "utf-8"
          elseif lsp == "texlab" then
            local texlab_runtime = vim.api.nvim_get_runtime_file("lsp/texlab.lua", false)[1]
            local texlab_defaults = dofile(texlab_runtime)
            local texlab_default_on_attach = texlab_defaults.on_attach
            lsp_common_config.on_attach = function(client, bufnr)
              if texlab_default_on_attach then
                texlab_default_on_attach(client, bufnr)
              end
              common_on_attach(client, bufnr)
              local map_opts = { buffer = bufnr, noremap = true, silent = true }
              vim.keymap.set("n", "<localleader>v", "<cmd>LspTexlabForward<cr>", map_opts)
              vim.keymap.set("n", "<localleader>b", "<cmd>LspTexlabBuild<cr>", map_opts)
            end
            local latexmkrc_exists = vim.fn.filereadable(vim.fn.getcwd() .. "/latexmkrc") == 1
              or vim.fn.filereadable(vim.fn.getcwd() .. "/.latexmkrc") == 1
            local args = {}
            if not latexmkrc_exists then
              args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" }
              -- args = { "-pdfxe", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
              -- args = { "-pdflua", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
            end
            lsp_common_config.settings = {
              texlab = {
                -- rootDirectory = vim.fn.getcwd(),
                auxDirectory = "latex.out",
                build = {
                  onSave = true, -- Automatically build latex on save
                  useFileList = true, -- use .fls file to determine which files to compile
                  args = args,
                },
                forwardSearch = {
                  executable = "zathura",
                  args = { "--synctex-forward", "%l:1:%f", "%p" },
                },
              },
              chktex = {
                onEdit = false,
                onOpenAndSave = true,
              },
            }
          elseif lsp == "lua_ls" then
            local lua_runtime = vim.api.nvim_get_runtime_file("lsp/lua_ls.lua", false)[1]
            local lua_defaults = dofile(lua_runtime)
            local lua_default_on_attach = lua_defaults.on_attach
            lsp_common_config.on_attach = function(client, bufnr)
              if lua_default_on_attach then
                lua_default_on_attach(client, bufnr)
              end
              load_plugin("lazydev.nvim")
              common_on_attach(client, bufnr)
            end
            if string.find(vim.fn.expand("%"), ".nvimrc.lua", 1, true) then
              -- lsp_common_config.autostart = false
            end
            lsp_common_config.settings = {
              Lua = {
                runtime = {
                  -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                  version = "LuaJIT",
                },
                diagnostics = {
                  -- Get the language server to recognize the `vim` global
                  globals = { "vim" },
                },
                workspace = {
                  -- Make the server aware of Neovim runtime files
                  -- library = vim.api.nvim_get_runtime_file("", true),
                  checkThirdParty = false,
                },
                -- Do not send telemetry data containing a randomized but unique identifier
                telemetry = {
                  enable = true,
                },
                codeLens = {
                  enable = true,
                },
                hint = {
                  enable = true,
                },
              },
            }
          elseif lsp == "gopls" then
            lsp_common_config.settings = {
              gopls = {
                semanticTokens = true,
                usePlaceholders = true,
                hints = {
                  assignVariableTypes = true,
                  compositeLiteralFields = true,
                  compositeLiteralTypes = true,
                  constantValues = true,
                  functionTypeParameters = true,
                  parameterNames = true,
                  rangeVariableTypes = true,
                },
              },
            }
          elseif lsp == "grammarly" then
            lsp_common_config.filetypes = { "markdown", "tex" }
            lsp_common_config.cmd = (function()
              if vim.fn.isdirectory(os.getenv("HOME") .. "/grammarly") == 1 then
                return {
                  os.getenv("HOME") .. "/grammarly/packages/grammarly-languageserver/bin/server.js",
                  "--stdio",
                }
              else
                return { "grammarly-languageserver", "--stdio" }
              end
            end)()
            lsp_common_config.init_options = {
              clientId = "client_BaDkMgx4X19X9UxxYRCXZo",
            }
            lsp_common_config.settings = {
              grammarly = {
                config = {
                  suggestions = {
                    MissingSpaces = false,
                  },
                },
              },
            }
          elseif lsp == "ltex" then
            lsp_common_config.settings = {
              ltex = {
                language = "en-US",
              },
            }
          elseif lsp == "nixd" then
            local dotfiles_dir = os.getenv("HOME") .. "/dotfiles"
            lsp_common_config.settings = {
              nixd = {
                nixpkgs = {
                  expr = "import (builtins.getFlake '" .. dotfiles_dir .. "').inputs.nixpkgs { }   ",
                },
                formatting = {
                  command = { "nixfmt" },
                },
              },
            }
          end
          vim.lsp.config(lsp, lsp_merge_project_config(lsp_common_config))
          vim.lsp.enable(lsp)
        end

        if python_commands then
          for name, spec in pairs(python_commands) do
            local handler = spec[1]
            if type(handler) == "function" then
              pcall(vim.api.nvim_del_user_command, name)
              pcall(vim.api.nvim_create_user_command, name, function()
                handler()
              end, { desc = spec.description })
            end
          end
        end

        local vim_version = vim.version()
        if vim_version.minor <= 10 then
          vim.diagnostic.jump = function(opts)
            if opts.count > 0 then
              for _ = 1, opts.count do
                vim.diagnostic.goto_next(opts)
              end
            else
              for _ = 1, math.abs(opts.count) do
                vim.diagnostic.goto_prev(opts)
              end
            end
          end
        end

        vim.keymap.set("n", "<space>e", changeDiagnostic, opts)
        -- vim.keymap.set('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
        vim.keymap.set("n", "[d", function()
          vim.diagnostic.jump({ count = -1, float = true })
        end, opts)
        vim.keymap.set("n", "]d", function()
          vim.diagnostic.jump({ count = 1, float = true })
        end, opts)
        vim.keymap.set("n", "<space>Q", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", opts)
        vim.keymap.set("n", "<space>q", "<cmd>Trouble diagnostics toggle<CR>", opts)
        vim.keymap.set("n", "<leader>d", showDocument, opts)

        -- vim.cmd [[au CursorHold <buffer> lua vim.diagnostic.open_float()]]

        -- UI Customization
        -- To instead override globally
        local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
        function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
          opts = opts or {}
          opts.border = "rounded"
          return orig_util_open_floating_preview(contents, syntax, opts, ...)
        end

        -- code len
        vim.keymap.set("n", "<leader>cl", "<cmd>lua vim.lsp.codelens.run()<CR>", opts)
        vim.cmd([[hi! link LspCodeLens specialkey]])

        -- format code
        local function formatBuf()
          local modes = { "i", "s" }
          local mode = vim.fn.mode()

          for _, v in pairs(modes) do
            if mode == v then
              return
            end
          end

          vim.lsp.buf.format({ async = true })
        end

        local function formatToggleHandler()
          if vim.g.format_on_save == 1 then
            vim.defer_fn(formatBuf, 1000)
          end
        end

        local function formatToggle()
          if not vim.g.format_on_save or vim.g.format_on_save == 0 then
            vim.g.format_on_save = 1
            vim.notify("Format On Save: ON")
          elseif vim.g.format_on_save == 1 then
            vim.g.format_on_save = 0
            vim.notify("Format On Save: OFF")
          end
        end

        -- defer 1000 ms for formatters
        -- vim.cmd[[ au BufWritePost <buffer> silent lua vim.defer_fn(formatBuf, 1000) ]]
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
          pattern = "*",
          callback = formatToggleHandler,
        })
        vim.api.nvim_create_user_command("AFToggle", formatToggle, { nargs = 0 })
        vim.keymap.set({ "n", "v" }, "<leader>af", formatBuf, { silent = true })
      end,
    },

    {
      -- can be used as formatter
      "nvimtools/none-ls.nvim",
      depedencies = {
        "nvimtools/none-ls-extras.nvim",
      },
      config = function()
        local null_ls = require("null-ls")
        local eslint = require("none-ls.diagnostics.eslint")
        local autopep8 = require("none-ls.formatting.autopep8")

        local isort_always_enabled = true

        null_ls.setup({
          sources = {
            eslint,
            -- null_ls.builtins.completion.spell,
            null_ls.builtins.formatting.prettier,
            null_ls.builtins.completion.tags,
            null_ls.builtins.code_actions.gitsigns,
            -- python
            autopep8.with({
              runtime_condition = function(params)
                if params.options.isort == true then
                  return false
                else
                  return true
                end
              end,
            }),
            null_ls.builtins.formatting.isort.with({
              runtime_condition = function(params)
                if isort_always_enabled == true then
                  return true
                end
                if params.options.isort == true then
                  return true
                else
                  return false
                end
              end,
            }),
          },
        })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "python" },
          callback = function(args)
            vim.api.nvim_buf_create_user_command(args.buf, "PythonOrganizeImports", function()
              vim.lsp.buf.format({ formatting_options = { isort = true } })
            end, {})
            vim.api.nvim_buf_create_user_command(args.buf, "PythonEnableIsortOnFormat", function()
              isort_always_enabled = true
            end, {})
          end,
        })
      end,
    },

    { "nvimtools/none-ls-extras.nvim" },

    {
      "ray-x/lsp_signature.nvim",
      config = function()
        require("lsp_signature").setup({
          bind = true, -- This is mandatory, otherwise border config won't get registered.
          floating_window = true,
          floating_window_above_cur_line = true,
          handler_opts = {
            border = "rounded",
          },
          hint_enable = false,
          transparency = 15,
          floating_window_off_x = function()
            local colnr = vim.api.nvim_win_get_cursor(0)[2] -- bu col number
            return colnr
          end,
          max_width = 40,
        })
      end,
    },

    {
      url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
      lazy = true,
      config = function()
        require("lsp_lines").setup()
      end,
    },

    {
      -- for code actions
      "kosayoda/nvim-lightbulb",
      config = function()
        local lightbulb = require("nvim-lightbulb")
        lightbulb.setup({
          autocmd = {
            enabled = true,
          },
          sign = {
            enabled = true,
            -- Text to show in the sign column.
            -- Must be between 1-2 characters.
            text = "💡",
            -- Highlight group to highlight the sign column text.
            hl = "LightBulbSign",
          },
          ignore = {
            clients = { "null-ls" },
          },
        })
      end,
    },

    {
      "j-hui/fidget.nvim",
      branch = "legacy",
      config = function()
        local opts = {
          sources = {
            ["null-ls"] = {
              ignore = true,
            },
            ["lua_ls"] = {
              ignore = true,
            },
          },
          fmt = {
            max_messages = 5,
          },
        }
        require("fidget").setup(opts)
      end,
    },

    {
      "folke/lazydev.nvim",
      lazy = true,
      opts = {
        library = {
          -- See the configuration section for more details
          -- Load luvit types when the `vim.uv` word is found
          { path = "luvit-meta/library", words = { "vim%.uv" } },
        },
      },
    },

    { "Bilal2453/luvit-meta", lazy = true },

    {
      "ldelossa/litee-calltree.nvim",
      cmd = { "IncomingCalls", "OutgoingCalls" },
      dependencies = { "ldelossa/litee.nvim" },
      config = function()
        -- configure the litee.nvim library
        require("litee.lib").setup({})
        -- configure litee-calltree.nvim
        require("litee.calltree").setup({
          keymaps = {
            expand = "o",
            collapse = "O",
          },
        })
        vim.api.nvim_create_user_command("IncomingCalls", vim.lsp.buf.incoming_calls, { nargs = 0 })
        vim.api.nvim_create_user_command("OutgoingCalls", vim.lsp.buf.outgoing_calls, { nargs = 0 })
        vim.keymap.set("n", "<c-l>", "<cmd>LTClearJumpHL<cr><cmd>nohlsearch<cr>", { silent = true })
      end,
    },

    {
      "smjonas/inc-rename.nvim",
      keys = "<leader>rn",
      config = function()
        require("inc_rename").setup({
          input_buffer_type = "dressing",
        })
        vim.keymap.set("n", "<leader>rn", function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end, { expr = true })
      end,
    },

    {
      "folke/trouble.nvim",
      dependencies = { "kyazdani42/nvim-web-devicons" },
      config = function()
        require("trouble").setup({
          focus = true,
        })
      end,
    },
  }

  return specs
end

return M
