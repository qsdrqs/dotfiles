--
--           | \ | | ___  __\ \   / /_ _|  \/  |     | |  | | | | / \
--           |  \| |/ _ \/ _ \ \ / / | || |\/| |     | |  | | | |/ _ \
--           | |\  |  __/ (_) \ V /  | || |  | |  _  | |__| |_| / ___ \
--           |_| \_|\___|\___/ \_/  |___|_|  |_| (_) |_____\___/_/   \_\
--------------------------------------------------------------------------------------

local use_nix = true
local lazypath
if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/nix") and use_nix then
  lazypath = vim.fn.stdpath("data") .. "/nix/lazy.nvim"
else
  lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
end
local loop_or_uv = vim.loop or vim.uv
if not loop_or_uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable", -- remove this if you want to bootstrap to HEAD
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local kind_icons_list = {
  Array               = '󰅪 ',
  Boolean             = ' ',
  BreakStatement      = '󰙧 ',
  Call                = '󰃷 ',
  CaseStatement       = '󱃙 ',
  Class               = ' ',
  Color               = '󰏘 ',
  Constant            = '󰏿 ',
  Constructor         = ' ',
  ContinueStatement   = '→ ',
  Copilot             = ' ',
  Declaration         = '󰙠 ',
  Delete              = '󰩺 ',
  DoStatement         = '󰑖 ',
  Enum                = ' ',
  EnumMember          = ' ',
  Event               = ' ',
  Field               = ' ',
  File                = '󰈔 ',
  Folder              = '󰉋 ',
  ForStatement        = '󰑖 ',
  Function            = '󰊕 ',
  Identifier          = '󰀫 ',
  IfStatement         = '󰇉 ',
  Interface           = ' ',
  Keyword             = '󰌋 ',
  List                = '󰅪 ',
  Log                 = '󰦪 ',
  Lsp                 = ' ',
  Macro               = '󰁌 ',
  MarkdownH1          = '󰉫 ',
  MarkdownH2          = '󰉬 ',
  MarkdownH3          = '󰉭 ',
  MarkdownH4          = '󰉮 ',
  MarkdownH5          = '󰉯 ',
  MarkdownH6          = '󰉰 ',
  Method              = '󰆧 ',
  Module              = '󰏗 ',
  Namespace           = '󰅩 ',
  Null                = '󰢤 ',
  Number              = '󰎠 ',
  Object              = '󰅩 ',
  Operator            = '󰆕 ',
  Package             = '󰆦 ',
  Property            = ' ',
  Reference           = '󰦾 ',
  Regex               = ' ',
  Repeat              = '󰑖 ',
  Scope               = '󰅩 ',
  Snippet             = '󰩫 ',
  Specifier           = '󰦪 ',
  Statement           = '󰅩 ',
  String              = '󰉾 ',
  Struct              = ' ',
  SwitchStatement     = '󰺟 ',
  Text                = ' ',
  Type                = ' ',
  TypeParameter       = '󰆩 ',
  Unit                = ' ',
  Value               = '󰎠 ',
  Variable            = '󰀫 ',
  WhileStatement      = '󰑖 ',
  Key                 = " ",
}

local kind_icons = {
  Text           = ' ',
  Method         = ' ',
  Function       = '󰊕 ',
  Constructor    = ' ',
  Field          = '󰇽 ',
  Variable       = ' ',
  Class          = 'ﴯ ',
  Interface      = ' ',
  Module         = " ",
  Property       = 'ﰠ ',
  Unit           = ' ',
  Value          = '󰎠 ',
  Enum           = ' ',
  Keyword        = '󰌋 ',
  Snippet        = ' ',
  Color          = '󰏘 ',
  File           = '󰈙 ',
  Reference      = ' ',
  Folder         = '󰉋 ',
  EnumMember     = ' ',
  Constant       = '󰏿 ',
  Struct         = ' ',
  Event          = ' ',
  Operator       = '󰆕 ',
  TypeParameter  = " ",
  TabNine        = ' ',
  String         = " ",
  Namespace      = " ",
  Number         = " ",
  Package        = " ",
  Boolean        = "◩ ",
  Array          = " ",
  Object         = " ",
  Key            = " ",
  Null           = "ﳠ ",
}

-- git navigations by vscode-neovim
local function vscode_next_hunk()
  require("vscode-neovim").action("workbench.action.editor.nextChange")
end
local function vscode_prev_hunk()
  require("vscode-neovim").action("workbench.action.editor.previousChange")
end

local plugins = {
  {'folke/lazy.nvim', lazy = false},
  {
    'nvim-lua/plenary.nvim',
    cmd = {
      "PlenaryProfile",
      "PlenaryProfileStop",
    },
    config = function()
      vim.api.nvim_create_user_command("PlenaryProfile", function() require'plenary.profile'.start("profile.log", {flame = true}) end, { nargs = 0 })
      vim.api.nvim_create_user_command("PlenaryProfileStop", function() require'plenary.profile'.stop() end, { nargs = 0 })
    end
  },
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      'jonarrien/telescope-cmdline.nvim',
      'tom-anders/telescope-vim-bookmarks.nvim',
    },
    keys = {
      "<leader>f",
      "<leader>b",
      "<leader>gs",
      "<leader>gg",
      "<leader>t",
    },
    cond = vim.g.vscode == nil,
    config = function()
      local action_set = require "telescope.actions.set"

      local function move_selection_next_5(prompt_bufnr)
        action_set.shift_selection(prompt_bufnr, 5)
      end

      local function move_selection_previous_5(prompt_bufnr)
        action_set.shift_selection(prompt_bufnr, -5)
      end

      local t = function(str)
        return vim.api.nvim_replace_termcodes(str, true, true, true)
      end
      local function move_left_7()
        return vim.api.nvim_feedkeys(t "7h", "n", true)
      end
      local function move_right_7()
        return vim.api.nvim_feedkeys(t "7l", "n", true)
      end

      local status_ok, trouble_telscope = pcall(require, "trouble.providers.telescope")
      local opts = {
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            },
            n = {
              ["K"] = move_selection_previous_5,
              ["J"] = move_selection_next_5,
              ["H"] = move_left_7,
              ["L"] = move_right_7,
              ["q"] = require("telescope.actions").close,
            },
          }
        }
      }
      if status_ok then
        opts.defaults.mappings.i["<C-t>"] = trouble_telscope.open_with_trouble
        opts.defaults.mappings.n["<C-t>"] = trouble_telscope.open_with_trouble
      end
      require('telescope').setup(opts)

      local function telescope_grep_string_visual()
        local saved_reg = vim.fn.getreg "v"
        vim.cmd [[noautocmd sil norm "vy]]
        local sele = vim.fn.getreg "v"
        vim.fn.setreg("v", saved_reg)
        require('telescope.builtin').grep_string({ search = sele })
      end

      -- lazy load telescope
      local telescope_buildin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>f', telescope_buildin.find_files, { silent = true })
      vim.keymap.set('n', '<leader>F', function() telescope_buildin.find_files{no_ignore=true} end, { silent = true })
      vim.keymap.set('n', '<leader>b', '<cmd>Telescope buffers<cr>', { silent = true })
      vim.keymap.set('n', '<leader>gs', '<cmd>Telescope grep_string <cr>', { silent = true })
      vim.keymap.set('v', '<leader>gs', telescope_grep_string_visual, { silent = true })
      vim.keymap.set('n', '<leader>gg', telescope_buildin.live_grep, { silent = true })
      vim.keymap.set('n', '<leader>t', '<cmd>Telescope builtin include_extensions=true <cr>', { silent = true })
      vim.keymap.set('n', '<leader>rc', '<cmd>Telescope command_history <cr>', { silent = true })
      vim.keymap.set('n', '<leader>rf', '<cmd>Telescope lsp_document_symbols<cr>', { silent = true })
      vim.keymap.set('n', '<leader>rw', '<cmd>Telescope lsp_dynamic_workspace_symbols<cr>', { silent = true })
      vim.keymap.set('n', '<leader>rl', '<cmd>Telescope current_buffer_fuzzy_find fuzzy=false <cr>', { silent = true })

    end
  },
  {'seandewar/sigsegvim', cmd = "Sigsegv"},
  {"Eandrju/cellular-automaton.nvim", cmd = "CellularAutomaton"},

  {
    'nvim-telescope/telescope-live-grep-args.nvim',
    lazy = true,
    keys = "<leader>gG",
    config = function()
      vim.keymap.set('n', '<leader>gG', require('telescope').extensions.live_grep_args.live_grep_args, { silent = true })
    end
  },

  {
    'kevinhwang91/nvim-bqf',
    config = function()
      vim.cmd [[
        hi BqfPreviewBorder guifg=#50a14f ctermfg=71
        hi link BqfPreviewRange Search
      ]]
      require('bqf').setup({
        auto_enable = true,
        auto_resize_height = false,
        preview = {
          win_height = 999, -- full screen
          win_vheight = 12,
          delay_syntax = 80,
          border_chars = {'┃', '┃', '━', '━', '┏', '┓', '┗', '┛', '█'},
          should_preview_cb = function(bufnr, qwinid)
            local ret = true
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local fsize = vim.fn.getfsize(bufname)
            if fsize > 100 * 1024 then
              -- skip file size greater than 100k
              ret = false
            elseif bufname:match('^fugitive://') then
              -- skip fugitive buffer
              ret = false
            end
            return ret
          end
        },
        -- make `drop` and `tab drop` to become preferred
        func_map = {
          drop = 'o',
          openc = 'O',
          split = '<C-s>',
          tabdrop = '<C-t>',
          tabc = '',
          ptogglemode = 'z,',
        },
        filter = {
          fzf = {
            action_for = {['ctrl-s'] = 'split', ['ctrl-t'] = 'tab drop'},
            extra_opts = {'--bind', 'ctrl-o:toggle-all', '--prompt', '> '}
          }
        }
      })
    end
  }, -- better quick fix

  {
    'kevinhwang91/nvim-hlslens',
    lazy = true,
    config = function()
      local kopts = {silent = true}

      vim.keymap.set('n', 'n',
      [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
      kopts)
      vim.keymap.set('n', 'N',
      [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
      kopts)
      vim.keymap.set('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

      vim.keymap.set('x', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('x', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('x', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.keymap.set('x', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

      require'hlslens'.setup {
        calm_down = false,
        nearest_only = true,
        nearest_float_when = 'auto',
        build_position_cb = function(plist, _, _, _)
            require("scrollbar.handlers.search").handler.show(plist.start_pos)
        end,
      }
    end
  },

  {
    "williamboman/mason.nvim",
    lazy = true,
    cmd = "Mason",
    init = function()
      vim.fn.setenv("PATH", vim.fn.getenv("PATH") .. ":" .. vim.fn.stdpath("data") .. "/mason/bin")
    end,
    config = function()
      require("mason").setup()
    end
  },

  {
    'mfussenegger/nvim-jdtls',
    dependencies = 'nvim-lspconfig',
    config = function()
      -- java
      local jdt_config = get_lsp_common_config()
      jdt_config.cmd = {

        -- 💀
        'java', -- or '/path/to/java11_or_newer/bin/java'
        -- depends on if `java` is in your $PATH env variable and if it points to the right version.

        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-Xms1g',
        '--add-modules=ALL-SYSTEM',
        '--add-opens', 'java.base/java.util=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

        -- 💀
        '-jar', vim.fn.stdpath('data') .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_1.6.400.v20210924-0641.jar",
        -- '-jar', os.getenv("HOME") .. "/.config/coc/extensions/coc-java-data/server/plugins/org.eclipse.equinox.launcher_1.6.400.v20210924-0641.jar",
        -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
        -- Must point to the                                                     Change this to
        -- eclipse.jdt.ls installation                                           the actual version


        -- 💀
        '-configuration', vim.fn.stdpath('data') .. "/mason/packages/jdtls/config_linux",
        -- '-configuration', os.getenv("HOME") .. "/.config/coc/extensions/coc-java-data/server/config_linux",
        -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
        -- Must point to the                      Change to one of `linux`, `win` or `mac`
        -- eclipse.jdt.ls installation            Depending on your system.


        -- 💀
        -- See `data directory configuration` section in the README
        '-data', os.getenv("HOME") .. '/.cache/jdtls/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

      }

      -- 💀
      -- This is the default if not provided, you can remove it. Or adjust as needed.
      -- One dedicated LSP server & client will be started per unique root_dir
      jdt_config.root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'})

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
              enabled = "all"
            }
          },
          implementationsCodeLens = true,
          referencesCodeLens = true,
        }
      }

      jdt_config.name = "jdtls"

      -- progress_report
      jdt_config.handlers = {
        -- disable default progress report
        ['language/status'] = function() end,
      }

      -- Language server `initializationOptions`
      -- You need to extend the `bundles` with paths to jar files
      -- if you want to use additional eclipse.jdt.ls plugins.
      --
      -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
      --
      -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
      local bundles = {
        vim.fn.glob(vim.fn.stdpath('data') .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
      }
      vim.list_extend(bundles, vim.split(vim.fn.glob(
          vim.fn.stdpath('data') .. "/mason/packages/java-test/extension/server/*.jar"), "\n"))
      jdt_config.init_options = {
        bundles = bundles,
      }

      vim.api.nvim_create_user_command("JdtDebugTestClass", "lua require('jdtls').test_class()", { nargs = 0 })
      vim.api.nvim_create_user_command("JdtDebugTestMethod", "lua require('jdtls').test_nearest_method()", { nargs = 0 })

      jdt_config.on_attach = function(client, bufnr)
        -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
        -- you make during a debug session immediately.
        -- Remove the option if you do not want that.
        require('jdtls').setup_dap({ hotcodereplace = 'auto' })
        common_on_attach(client, bufnr)
        require('jdtls.dap').setup_dap_main_class_configs()
      end
      -- vim.cmd[[ autocmd FileType java lua require('jdtls').start_or_attach(jdt_config)]]
        require('jdtls.setup').add_commands()
        require('jdtls').start_or_attach(jdt_config)
    end
  },

  {
    "mrcjkb/rustaceanvim",
    dependencies = 'nvim-lspconfig',
    config = function()
      vim.g.rustaceanvim = function()
        local extension_path = vim.fn.stdpath('data') .. '/mason/'
        local codelldb_path = extension_path .. 'bin/codelldb'
        local liblldb_path = extension_path .. 'packages/codelldb/extension/lldb/lib/liblldb.so'

        local lsp_config = get_lsp_common_config()
        lsp_config.capabilities.offsetEncoding = nil

        local cfg = require('rustaceanvim.config')
        return {
          server = lsp_config,
          dap = {
            adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
          },
        }
      end
      vim.api.nvim_buf_create_user_command(0, "RustLspExpandMacro", function() vim.cmd.RustLsp('expandMacro') end, {})
    end
  },

  {
    'p00f/clangd_extensions.nvim',
    dependencies = 'nvim-lspconfig',
  },

  {
    'neovim/nvim-lspconfig',
    config = function()
      -- vim.lsp.set_log_level('DEBUG')
      vim.lsp.set_log_level('OFF')

      local lspconfig = require('lspconfig')

      function common_on_attach(client, bufnr)
        -- Enable completion triggered by <c-x><c-o>
        vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

        -- codelens
        vim.api.nvim_create_autocmd({"InsertLeave", "TextChanged", "BufEnter"}, {
          pattern = "*",
          callback = function()
            vim.lsp.codelens.refresh()
          end
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
        vim.lsp.inlay_hint.enable(bufnr, true)

      end

      local function showDocument()
        local clients = vim.lsp.get_active_clients()
        if next(clients) ~= nil then
          vim.lsp.buf.hover()
        elseif vim.o.filetype == "help" or vim.o.filetype == "vim" or vim.o.filetype == "lua" then
          vim.cmd("execute 'h '.expand('<cword>')")
        else
          vim.cmd("execute '!' . &keywordprg . ' ' . expand('<cword>')")
        end
      end

      local opts = { noremap=true, silent=true }

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      -- vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'gd', '<cmd>Trouble lsp_definitions<CR>', opts)
      -- vim.keymap.set('n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
      vim.keymap.set('n', 'gr', '<cmd>Trouble lsp_references<CR>', opts)

      vim.keymap.set('n', 'gi', '<cmd>Trouble lsp_implementations<cr>', opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
      vim.keymap.set('n', '<space>aa', vim.lsp.buf.add_workspace_folder, opts)
      vim.keymap.set('n', '<space>ar', vim.lsp.buf.remove_workspace_folder, opts)
      vim.keymap.set('n', '<space>al', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
      vim.keymap.set('n', '<space>D', '<cmd>Trouble lsp_type_definitions<CR>', opts)
      -- vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
      vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"c", "cpp"},
        callback = function(args)
          vim.keymap.set('n', 'gh', '<cmd>ClangdSwitchSourceHeader <CR>', { buffer = true, silent = true, noremap = true })
        end
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
        }
      })
      virtualLineEnabled = false

      local function changeDiagnostic()
        require("lsp_lines") -- lazy load lsp_lines
        if virtualLineEnabled == false then
          vim.diagnostic.config({
            virtual_text = false,
            virtual_lines = true
          })
          virtualLineEnabled = true
        else
          vim.diagnostic.config({
            -- virtual_text = true,
            virtual_lines = false
          })
          virtualLineEnabled = false
        end
      end

      function get_lsp_common_config()
        local capabilities = require('cmp_nvim_lsp').default_capabilities()
        capabilities.textDocument.foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true
        }
        local config = {
          on_attach = common_on_attach,
          capabilities = capabilities,
          flags = {
            debounce_text_changes = 150,
          },
          handlers = {
            ["textDocument/publishDiagnostics"] = vim.lsp.with(
              vim.lsp.diagnostic.on_publish_diagnostics, {
                signs = true,
                underline = true,
                update_in_insert = false,
              }
            ),
          }
        }
        return config
      end

      -- 'rust_analyzer' are handled by rust-tools.
      local servers = {
        'texlab', 'lua_ls', 'vimls', 'hls', 'tsserver',
        "cmake", "gopls", "bashls", "bufls", "grammarly", "nil_ls",
        'clangd',
      }

      -- add my magic python lsp
      local ok, pycfg = pcall(require, 'dotfiles.private.magic_py_lsp')
      if not ok or pycfg.config == nil then
        servers[#servers+1] = 'pyright'
      else
        require('lspconfig.configs')[pycfg.name] = pycfg.config
        servers[#servers+1] = pycfg.name
      end
      for _, lsp in ipairs(servers) do
        local lsp_common_config = get_lsp_common_config()
        if lsp == 'tsserver' then
          -- lsp_common_config.root_dir = require('lspconfig.util').root_pattern("*")
        elseif lsp == "pyright" or lsp == pycfg.name then
          lsp_common_config.settings = {
            python = {
              analysis = {
                diagnosticSeverityOverrides = {
                  -- reportGeneralTypeIssues = "warning"
                },
              }
            }
          }
        elseif lsp == "clangd" then
          lsp_common_config.cmd = { "clangd", "--header-insertion-decorators=0", "-header-insertion=never",
            "--background-index" }
          lsp_common_config.filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }
          -- set offset encoding
          lsp_common_config.capabilities.offsetEncoding = 'utf-8'
        elseif lsp == "texlab" then
          lsp_common_config.on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>v', '<cmd>TexlabForward<cr>', { noremap=true, silent=true })
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>b', '<cmd>TexlabBuild<cr>', { noremap=true, silent=true })
          end
          lsp_common_config.settings = {
            texlab = {
              -- rootDirectory = vim.fn.getcwd(),
              auxDirectory = "latex.out",
              build = {
                onSave = true, -- Automatically build latex on save
                -- args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
                -- args = { "-pdfxe", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
                args = { "-pdflua", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
              },
              forwardSearch = {
                executable = "zathura",
                args = {
                  '--synctex-forward',
                  '%l:1:%f',
                  '%p',
                },
              },
            },
            chktex = {
              onEdit = false,
              onOpenAndSave = true
            }
          }
        elseif lsp == "lua_ls" then
          if string.find(vim.fn.expand('%'), '.nvimrc.lua', 1, true) then
            -- lsp_common_config.autostart = false
          end
          lsp_common_config.settings = {
            Lua = {
              runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
              },
              diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'},
              },
              workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true),
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
              }
            }
          }
          lsp_common_config.on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
            local semantic = client.config.capabilities.textDocument.semanticTokens
            client.server_capabilities.semanticTokensProvider = {
              full = true,
              legend = {tokenModifiers = semantic.tokenModifiers, tokenTypes = semantic.tokenTypes},
              range = true,
            }
          end
        elseif lsp == "grammarly" then
          lsp_common_config.filetypes = { "markdown", "tex" }
          lsp_common_config.cmd = (function()
            if vim.fn.isdirectory(os.getenv("HOME") .. "/grammarly") == 1 then
              return {os.getenv("HOME") .. "/grammarly/packages/grammarly-languageserver/bin/server.js", "--stdio"}
            else
              return {"grammarly-languageserver", "--stdio"}
            end
          end)()
          lsp_common_config.init_options = {
            clientId = "client_BaDkMgx4X19X9UxxYRCXZo"
          }
          lsp_common_config.settings = {
            grammarly = {
              config = {
                suggestions = {
                  MissingSpaces = false
                }
              }
            }
          }
        elseif lsp == "nil_ls" then
          lsp_common_config.settings = {
            ['nil'] = {
              formatting = {
                command = { "nixpkgs-fmt" }
              },
              nix = {
                maxMemoryMB = math.floor((vim.uv.get_free_memory() * 0.9) / math.pow(2, 20)),
                flake = {
                  autoArchive = false,
                  autoEvalInputs = true,
                  nixpkgsInputName = "nixpkgs",
                }
              }
            }
          }
        end
        lspconfig[lsp].setup(lsp_common_config)
      end


      vim.keymap.set('n', '<space>e', changeDiagnostic, opts)
      -- vim.keymap.set('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
      vim.keymap.set('n', '<space>Q', '<cmd>TroubleToggle document_diagnostics<CR>', opts)
      vim.keymap.set('n', '<space>q', '<cmd>TroubleToggle workspace_diagnostics<CR>', opts)
      vim.keymap.set('n', '<leader>d', showDocument, opts)

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
      vim.keymap.set('n', '<leader>cl', '<cmd>lua vim.lsp.codelens.run()<CR>', opts)
      vim.cmd [[hi! link LspCodeLens specialkey]]

      -- format code
      local function formatBuf()
        local modes = {"i", "s"}
        local mode = vim.fn.mode()

        for _,v in pairs(modes) do
          if mode == v then
            return
          end
        end

        vim.lsp.buf.format{ async = true }
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
      vim.api.nvim_create_autocmd({"BufWritePost"}, {
        pattern = "*",
        callback = formatToggleHandler,
      })
      vim.api.nvim_create_user_command("AFToggle", formatToggle, { nargs = 0 })
      vim.keymap.set({"n", "v"}, "<leader>af", formatBuf, { silent = true })

    end
  },

  {
    "luukvbaal/statuscol.nvim",
    branch = "0.10",
    cond = vim.g.vscode == nil,
    config = function()
      local builtin = require("statuscol.builtin")
      vim.o.numberwidth = vim.o.numberwidth + 2 -- fix numberwidth mismatch
      require("statuscol").setup({
        -- Builtin line number string options for ScLn() segment
        thousands = false,     -- or line number thousands separator string ("." / ",")
        relculright = true,   -- whether to right-align the cursor line number with 'relativenumber' set
        bt_ignore = {"nofile"},
        -- Builtin 'statuscolumn' options
        setopt = true,         -- whether to set the 'statuscolumn', providing builtin click actions
        -- Default segments (fold -> sign -> line number + separator)
        segments = {
          {
            sign = { name = { ".*" }, namespace = { ".*" }, maxwidth = 1, colwidth = 2},
            click = "v:lua.ScSa"
          },
          {
            text = { builtin.lnumfunc },
            condition = { true, builtin.not_empty },
            click = "v:lua.ScLa",
          },
          {
            sign = { namespace = {"gitsigns"},  maxwidth = 1, colwidth = 1, auto = false },
            click = "v:lua.ScSa",
          },
          { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
        },
        ft_ignore = {
          "toggleterm",
          "dapui_scopes",
          "dapui_breakpoints",
          "dapui_stacks",
          "dapui_watches",
          "dap-repl"
        }, -- lua table with filetypes for which 'statuscolumn' will be unset
        -- Click actions
        clickhandlers = {
          Lnum                    = builtin.lnum_click,
          FoldClose               = builtin.foldclose_click,
          FoldOpen                = builtin.foldopen_click,
          FoldOther               = builtin.foldother_click,
          DapBreakpointRejected   = builtin.toggle_breakpoint,
          DapBreakpoint           = builtin.toggle_breakpoint,
          DapBreakpointCondition  = builtin.toggle_breakpoint,
          DiagnosticSignError     = builtin.diagnostic_click,
          DiagnosticSignHint      = builtin.diagnostic_click,
          DiagnosticSignInfo      = builtin.diagnostic_click,
          DiagnosticSignWarn      = builtin.diagnostic_click,
          GitSignsTopdelete       = builtin.gitsigns_click,
          GitSignsUntracked       = builtin.gitsigns_click,
          GitSignsAdd             = builtin.gitsigns_click,
          GitSignsChangedelete    = builtin.gitsigns_click,
          GitSignsDelete          = builtin.gitsigns_click,
          gitsigns_extmark_signs_ = builtin.gitsigns_click,
        }
      })
    end
  },

  {
    -- for code actions
    'kosayoda/nvim-lightbulb',
    config = function()
      local lightbulb = require('nvim-lightbulb')
      lightbulb.setup {
        autocmd = {
          enabled = true
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
          clients = {"null-ls"}
        },
      }
    end
  },

  {
    'j-hui/fidget.nvim',
    branch = "legacy",
    config = function()
      local opts = {
        sources = {
          ["null-ls"] = {
              ignore = true
          },
          ["lua_ls"] = {
            ignore = true
          }
        },
        fmt = {
          max_messages = 5,
        }
      }
      require"fidget".setup(opts)
    end
  },

  {'kyazdani42/nvim-web-devicons'},

  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    cond = vim.g.vscode == nil,
    opts = {}
  },

  {
    "okuuva/auto-save.nvim",
    event = {"InsertLeave", "TextChanged", "WinLeave", "BufLeave"},
    cond = vim.g.vscode == nil,
    opts = {
      execution_message = {
        enabled = false,
      },
      trigger_events = { -- See :h events
        immediate_save = { "BufLeave", "FocusLost", "VimLeave" }, -- vim events that trigger an immediate save
        defer_save = { "InsertLeave", "TextChanged" }, -- vim events that trigger a deferred save (saves after `debounce_delay`)
        cancel_defered_save = { "InsertEnter" }, -- vim events that cancel a pending deferred save
      },
    }
  },

  {
    -- can be used as formatter
    "nvimtools/none-ls.nvim",
    depedencies = {
      "nvimtools/none-ls-extras.nvim",
    },
    config = function()
      local null_ls = require("null-ls")
      local eslint =  require('none-ls.diagnostics.eslint')
      local autopep8 = require('dotfiles.none-ls.autopep8')

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
            end
          }),
          null_ls.builtins.formatting.isort.with({
            runtime_condition = function(params)
              if params.options.isort == true then
                return true
              else
                return false
              end
            end
          }),
        },
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"python"},
        callback = function(args)
          vim.api.nvim_buf_create_user_command(args.buf, "PythonOrganizeImports", function()
            vim.lsp.buf.format({formatting_options = {isort = true}})
          end, {})
        end
      })
    end
  },
  { "nvimtools/none-ls-extras.nvim" },

  -- complete
  {'hrsh7th/vim-vsnip'},
  {
    'hrsh7th/cmp-nvim-lsp',
    depedencies = {"neovim/nvim-lspconfig"}
  },
  { 'hrsh7th/cmp-nvim-lua',  },
  { 'hrsh7th/cmp-path', },
  { 'hrsh7th/cmp-buffer',  },
  { 'hrsh7th/cmp-omni',  },
  { 'hrsh7th/cmp-nvim-lsp-signature-help', },
  {
    'uga-rosa/cmp-dictionary',
    config = function()
      require("cmp_dictionary").setup({ dic = { ["markdown,tex,text"] = { "/usr/share/dict/words" } }, })
      require("cmp_dictionary").update()
    end
  },
  {
    'rcarriga/cmp-dap',
    config = function()
      require("cmp").setup({
        enabled = function()
          return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt"
          or require("cmp_dap").is_dap_buffer()
        end
      })

      require("cmp").setup.filetype({ "dap-repl", "dapui_watches" }, {
        sources = {
          { name = "dap" },
        },
      })
    end
  },
  {
    'hrsh7th/cmp-cmdline',
    lazy = true,
    keys = {"/", {":", mode = {'v', 'n'}}},
    cond = vim.g.vscode == nil
          and vim.fn.getfsize(vim.fn.expand('%')) <= (1024 * 1024 * 100)
          and vim.fn.line('$') <= 100000
          and vim.g.started_by_firenvim == nil,
    config = function()
      local status_ok, cmp = pcall(require, "cmp")
      if not status_ok then
        return
      end

      -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline('/', {
        sources = {
          { name = 'buffer' }
        },
      })

      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        sources = cmp.config.sources({
          { name = 'path' },
          { name = 'cmdline' }
        }),

      })
    end
  },

  {
    'ray-x/lsp_signature.nvim',
    config = function()
      require "lsp_signature".setup({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
        floating_window = true,
        floating_window_above_cur_line = true,
        handler_opts = {
          border = "rounded"
        },
        hint_enable = false,
        transparency = 15,
        floating_window_off_x = function()
          local colnr = vim.api.nvim_win_get_cursor(0)[2] -- bu col number
          return colnr
        end,
        max_width = 40,
      })
    end
  },

  {
    'hrsh7th/nvim-cmp',
    dependencies = {"L3MON4D3/LuaSnip", 'saadparwaiz1/cmp_luasnip'},
    config = function()
      local t = function(str)
        return vim.api.nvim_replace_termcodes(str, true, true, true)
      end
      local cmp = require('cmp')
      local ls = require('luasnip')

      cmp.setup{
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        formatting = {
          format = function(entry, vim_item)
            -- Kind icons
            if entry.source.name == 'cmp_tabnine' then
              vim_item.kind = "TabNine"
            end
            vim_item.kind = string.format('%s', kind_icons_list[vim_item.kind]) -- This concatonates the icons with the name of the item kind
            -- tabnine
            -- limit width to 50
            local abbr_len = string.len(vim_item.abbr)
            local width = 50
            if abbr_len > width then
              vim_item.abbr = string.sub(vim_item.abbr, 1, width)
            elseif abbr_len > width / 2 then
              vim_item.abbr = vim_item.abbr .. string.rep(" ", width - abbr_len)
            end
            -- Source
            --[[ vim_item.menu = ({
              buffer = "[Buffer]",
              nvim_lsp = "[LSP]",
              luasnip = "[Snip]",
              ultisnips = "[Snip]",
              nvim_lua = "[Lua]",
              latex_symbols = "[LaTeX]",
            })[entry.source.name] ]]
            return vim_item
          end,
          fields=  {
            'kind',
            'abbr',
            'menu',
          }
        },

        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            -- Use vsnip to handles snips provided by lsp. Ultisnips has problems.
            -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.

            ls.lsp_expand(args.body) -- For `luasnip` users.
            -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
            -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
          ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
          ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
          ['<C-e>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
          ['<C-j>'] = cmp.mapping(function(fallback)
            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
          end, {"i","s","c"}),
          ['<C-k>'] = cmp.mapping(function(fallback)
            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
          end, {"i","s","c"}),

          ["<Tab>"] = cmp.mapping({
            c = function()
              if cmp.visible() then
                cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
              else
                cmp.complete()
              end
            end,
            i = function(fallback)
              local ok, copilot_keys = pcall(vim.fn["copilot#Accept"], "empty")
              if not ok then
                copilot_keys = "empty"
              end
              local luasnip_jump_forward = ls.expand_or_jumpable()
              if cmp.visible() then
                -- cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
                cmp.confirm()
              elseif copilot_keys ~= "empty" then
                vim.api.nvim_feedkeys(copilot_keys, "i", true)
              elseif luasnip_jump_forward == true then
                ls.expand_or_jump()
              else
                vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
                -- fallback()
              end
            end,
            s = function(fallback)
              if ls.jumpable(1) == true then
                ls.jump(1)
              else
                fallback()
              end
            end
          }),
          ["<S-Tab>"] = cmp.mapping({
            c = function()
              if cmp.visible() then
                cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
              else
                cmp.complete()
              end
            end,
            i = function(fallback)
              if cmp.visible() then
                cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
              elseif ls.jumpable(-1) == true then
                ls.jump(-1)
              else
                fallback()
              end
            end,
            s = function(fallback)
              if ls.jumpable(-1) == true then
                ls.jump(-1)
              else
                fallback()
              end
            end
          }),
        }),
        sources = cmp.config.sources({
          -- { name = 'ultisnips' }, -- For ultisnips users.
          -- { name = 'nvim_lsp_signature_help' },
          { name = 'nvim_lsp' },
          -- { name = 'omni' },
          { name = 'dictionary', keyword_length = 2 },
          { name = 'path' },
          { name = 'nvim_lua' },
          { name = 'buffer' },
          { name = 'luasnip' }, -- For luasnip users.
          -- { name = 'snippy' }, -- For snippy users.
        }),

        completion = {
          -- autocomplete = true,
          completeopt = 'menu,menuone,noinsert'
        },

      }

      -- vim.keymap.set('i', '<C-x><C-o>', '<Cmd>lua require("cmp").complete()<CR>', { silent = true })

      vim.api.nvim_create_user_command("CmpDisable", function()
        cmp.setup{enabled=false}
      end, {nargs = 0})
      vim.api.nvim_create_user_command("CmpEnable", function()
        cmp.setup{enabled=true}
      end, {nargs = 0})
    end
  },

  {'kevinhwang91/promise-async'},
  {
    -- permanent undo file
    'kevinhwang91/nvim-fundo',
    dependencies = {'kevinhwang91/promise-async'},
    keys = {'u', "<C-r>"},
    cond = vim.g.vscode == nil,
    build = function()
      require('fundo').install()
    end,
  },

  {
    -- smart fold
    'kevinhwang91/nvim-ufo',
    dependencies = {'kevinhwang91/promise-async'},
    config = function()
      -- FIXME: may fix this
      -- if treesitter is going to load, it need to be loaded before ufo
      if vim.b.treesitter_disable ~= 1 then
        require('lazy').load {
          plugins = {
            'nvim-treesitter',
          }
        }
      end

      vim.o.foldcolumn = '1'
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true


      local function handler(virt_text, lnum, end_lnum, width, truncate, ctx)
        local result = {}

        local counts = (" %d"):format(end_lnum - lnum)
        local prefix = "⋯⋯  "
        local suffix = "  ⋯⋯"
        local padding = ""

        local end_virt_text = ctx.get_fold_virt_text(end_lnum)
        -- trim the end_virt_text
        local leader_num = 0
        for i = 1, #end_virt_text[1][1] do
          local c = end_virt_text[1][1]:sub(i, i)
          if c == ' ' then
            leader_num = leader_num + 1
          else
            break
          end
        end
        local first_end_text = end_virt_text[1][1]:sub(leader_num + 1, -1)
        if first_end_text == "" then
          table.remove(end_virt_text, 1)
        else
          end_virt_text[1][1] = first_end_text
        end

        local start_virt_text = ctx.get_fold_virt_text(lnum)

        local end_virt_text_width = 0
        for _, item in ipairs(end_virt_text) do
          end_virt_text_width = end_virt_text_width + vim.fn.strdisplaywidth(item[1])
        end

        -- add left parenthesis if missing
        local maybe_left_parenthesis = nil
        if end_virt_text[1] ~= nil and start_virt_text[#start_virt_text] ~= nil then
          if string.find(end_virt_text[1][1], "}", 1, true) and not string.find(start_virt_text[#start_virt_text][1], "{", 1, true) then
            maybe_left_parenthesis = {" {", end_virt_text[1][2]}
          end
          if string.find(end_virt_text[1][1], "]", 1, true) and not string.find(start_virt_text[#start_virt_text][1], "[", 1, true) then
            maybe_left_parenthesis = {" [", end_virt_text[1][2]}
          end
          if string.find(end_virt_text[1][1], ")", 1, true) and not string.find(start_virt_text[#start_virt_text][1], "(", 1, true) then
            maybe_left_parenthesis = {" (", end_virt_text[1][2]}
          end
        end

        if end_virt_text_width > 5 then
          end_virt_text = {}
          end_virt_text_width =  0
        end

        local sufWidth = (2 * vim.fn.strdisplaywidth(suffix))
        + vim.fn.strdisplaywidth(counts)
        + end_virt_text_width

        local target_width = width - sufWidth
        local cur_width = 0

        for _, chunk in ipairs(virt_text) do
          local chunk_text = chunk[1]

          local chunk_width = vim.fn.strdisplaywidth(chunk_text)
          if target_width > cur_width + chunk_width then
            table.insert(result, chunk)
          else
            chunk_text = truncate(chunk_text, target_width - cur_width)
            local hl_group = chunk[2]
            table.insert(result, { chunk_text, hl_group })
            chunk_width = vim.fn.strdisplaywidth(chunk_text)

            if cur_width + chunk_width < target_width then
              padding = padding .. (" "):rep(target_width - cur_width - chunk_width)
            end
            break
          end
          cur_width = cur_width + chunk_width
        end

        if maybe_left_parenthesis then
          table.insert(result, maybe_left_parenthesis)
        end
        table.insert(result, { "...", "UfoFoldedEllipsis" })
        -- table.insert(result, { counts, "MoreMsg" })
        -- table.insert(result, { suffix, "UfoFoldedEllipsis" })

        for _, v in ipairs(end_virt_text) do
          table.insert(result, v)
        end

        table.insert(result, { padding, "" })

        return result
      end

      local function customizeSelector(bufnr)
          local function handleFallbackException(err, providerName)
              if type(err) == 'string' and err:match('UfoFallbackException') then
                  return require('ufo').getFolds(providerName, bufnr)
              else
                  return require('promise').reject(err)
              end
          end

          return require('ufo').getFolds('lsp', bufnr):catch(function(err)
              return handleFallbackException(err, 'treesitter')
          end):catch(function(err)
              return handleFallbackException(err, 'indent')
          end)
      end

      require('ufo').setup{
        provider_selector = function(bufnr, filetype, buftype)
          return customizeSelector
        end,
        enable_get_fold_virt_text = true,
        fold_virt_text_handler = handler
      }
      -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
    end
  },

  {
    'willothy/flatten.nvim',
    lazy = false,
    config = function()
      local saved_terminal
      require('flatten').setup {
        window = {
          open = "alternate",
        },
        callbacks = {
          pre_open = function()
            local term = require("toggleterm.terminal")
            local termid = term.get_focused_id()
            saved_terminal = term.get(termid)
          end,
          post_open = function(bufnr, winnr, ft, is_blocking)
            if is_blocking and saved_terminal then
              saved_terminal:close()
            end
          end
        }
      }
    end
  },

  {
    "akinsho/toggleterm.nvim",
    keys = {
      "<localleader>t",
      "<C-`>",
      {"<C-Space>", mode = 'n'},
      "<localleader>T",
      "<leader>ya",
    },
    cmd = {
      "YaziToggle",
      "ZjumpToggle"
    },
    config = function()
      require("toggleterm").setup {
        size = function(term)
          if term.direction == "horizontal" then
            return vim.o.lines * 0.25
          elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
          end
        end,
        open_mapping = [[<c-`>]],
        winbar = {
          enabled = true,
        }
      }
      vim.keymap.set('n', '<localleader>t', "<cmd>exe v:count1 . 'ToggleTerm direction=vertical'<cr>")
      vim.keymap.set({'n', 't'}, '<C-Space>', "<cmd>exe v:count1 . 'ToggleTerm'<cr>")

      -- lazy git
      local Terminal  = require('toggleterm.terminal').Terminal

      local function lazygit_toggle()
        -- lazy call lazygit, to get currect cwd
        local lazygit = Terminal:new({
          cmd = "lazygit",
          hidden = true,
          direction = "float",
        })
        lazygit:toggle()
      end

      local function yazi_toggle()
        vim.fn.setenv("CURR_FILE", vim.fn.expand("%"))
        local cmd = "yazi $CURR_FILE"
        local tmp_file = nil
        if vim.g.remote_ui == 1 then
          if vim.fn.executable("echoerr") == 0 then
            vim.notify("echoerr is not available", vim.log.levels.ERROR)
            return
          end
          vim.fn.setenv("EDITOR", "echoerr")
          tmp_file = vim.fn.tempname()
          cmd = "QUIT_ON_OPEN=1 yazi $CURR_FILE 2>" .. tmp_file
        end
        local yazi = Terminal:new({
          cmd = cmd,
          hidden = false,
          direction = "float",
          float_opts = {
            width = vim.fn.float2nr(0.7 * vim.o.columns),
            height = vim.fn.float2nr(0.7 * vim.o.lines),
          },
          on_exit = function(_, _, exit_code)
            if tmp_file then
              local f = io.open(tmp_file, "r")
              if f ~= nil then
                local content = f:read("*a")
                f:close()
                vim.defer_fn(function()
                  vim.cmd("edit " .. content)
                end, 0)
              end
              vim.fn.delete(tmp_file)
            end
          end,
        })
        yazi:toggle()
      end

      local function zjump_toggle()
        local tmp_file = vim.fn.tempname()
        local zjump = Terminal:new({
          cmd = "zoxide query --exclude " .. vim.fn.getcwd() .. " --interactive 1>" .. tmp_file,
          hidden = false,
          direction = "float",
          float_opts = {
            width = vim.fn.float2nr(0.7 * vim.o.columns),
            height = vim.fn.float2nr(0.7 * vim.o.lines),
          },
          on_exit = function(_, _, exit_code)
            if exit_code == 0 then
              local f = io.open(tmp_file, "r")
              if f ~= nil then
                local path = f:read("*a")
                f:close()
                vim.cmd("cd " .. path)
                -- try to restore session
                vim.api.nvim_create_autocmd("User", {
                  pattern = "DirenvLoaded",
                  callback = function()
                    vim.defer_fn(function()
                      require('auto-session').RestoreSession()
                    end, 0)
                  end,
                  once = true,
                })
              else
                vim.notify("failed to read zoxide output", vim.log.levels.ERROR)
              end
            end
            vim.fn.delete(tmp_file)
          end,
        })
        zjump:toggle()
      end

      vim.api.nvim_create_user_command("YaziToggle", yazi_toggle, {nargs = 0})
      vim.api.nvim_create_user_command("ZjumpToggle", zjump_toggle, {nargs = 0})

      vim.keymap.set("n", "<c-g>", lazygit_toggle, {noremap = true, silent = true})
      vim.keymap.set("n", "<leader>ya", yazi_toggle, {noremap = true, silent = true})

      -- repl
      vim.keymap.set("n", "<c-c><c-c>", "<cmd>ToggleTermSendCurrentLine<cr>")
      vim.keymap.set("v", "<c-c><c-c>", "<cmd>'<,'>ToggleTermSendVisualLines<cr>")
    end
  },

  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      if vim.g.treesitter_disable == true or vim.g.vscode then
        return
      end
      require 'nvim-treesitter.configs'.setup {
        -- One of "all", or a list of languages
        ensure_installed = {"c", "cpp", "java", "python", "javascript", "rust", "markdown"},

        -- Install languages synchronously (only applied to `ensure_installed`)
        sync_install = false,


        -- List of parsers to ignore installing
        -- ignore_install = { "javascript" },

        highlight = {
          -- `false` will disable the whole extension
          enable = true,

          -- list of language that will be disabled
          disable = function(lang, bufnr) -- Disable in large C++ buffers
            return vim.api.nvim_buf_line_count(bufnr) > 20000
          end,

          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = true,
          custom_captures = {
            -- disable comment hightlight (for javadoc)
            ["comment"] = "NONE",
          }
        },
        indent = {
          enable = false
        },
      }
      -- matlab
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.matlab = {
        install_info = {
          url = "https://github.com/mstanciu552/tree-sitter-matlab.git",
          files = { "src/parser.c" },
          branch= 'main'
        },
        filetype = "matlab", -- if filetype does not agrees with parser name
      }
    end
  },

  -- {
  --     "sustech-data/wildfire.nvim",
  --     dependencies = { "nvim-treesitter/nvim-treesitter" },
  --     keys = { "<CR>" },
  --     cond = function()
  --       return vim.g.treesitter_disable ~= true
  --     end,
  --     config = function()
  --         require("wildfire").setup({
  --           filetype_exclude = { "qf", "vim" }
  --         })
  --     end,
  -- },

  {
    'nvim-treesitter/playground',
    lazy = true,
    cmd = {"TSPlaygroundToggle"},
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      require "nvim-treesitter.configs".setup {
        playground = {
          enable = true,
          disable = {},
          updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
          persist_queries = false, -- Whether the query persists across vim sessions
          keybindings = {
            toggle_query_editor = 'o',
            toggle_hl_groups = 'i',
            toggle_injected_languages = 't',
            toggle_anonymous_nodes = 'a',
            toggle_language_display = 'I',
            focus_language = 'f',
            unfocus_language = 'F',
            update = 'R',
            goto_node = '<cr>',
            show_help = '?',
          },
        }
      }
    end
  },

  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    lazy = true,
    cond = function()
      return vim.b.treesitter_disable ~= true
    end,
    config = function()
      if vim.g.treesitter_disable == true then
        return
      end
      local opts = {
        textobjects = {
          select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["ap"] = "@parameter.outer",
              ["ip"] = "@parameter.inner",
            },
          },
          swap = {
            enable = true,
            swap_next = {
              ["<leader>sl"] = "@parameter.inner",
            },
            swap_previous = {
              ["<leader>sh"] = "@parameter.inner",
            },
          },
        },
      }
      if vim.bo.filetype ~= "lua" then
        opts.textobjects.move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              ["]m"] = "@function.outer",
            },
            goto_next_end = {
              ["]M"] = "@function.outer",
            },
            goto_previous_start = {
              ["[m"] = "@function.outer",
            },
            goto_previous_end = {
              ["[M"] = "@function.outer",
            },
        }
      end
      require'nvim-treesitter.configs'.setup(opts)
    end
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    lazy = true,
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      local ok, treesitter = pcall(require, 'nvim-treesitter')
      if vim.b.treesitter_disable ~= 1 then
        vim.g.indent_blankline_show_current_context = true
        vim.g.indent_blankline_show_current_context_start = true
      end
      local highlight = {
        "Color1",
        "Color2",
        "Color3",
        "Color4",
        "Color5",
        "Color6",
      }
      local hooks = require "ibl.hooks"
      vim.g.rainbow_delimiters = { highlight = highlight }
      require("ibl").setup {
        indent = {
          -- char = '▏',
          -- context_char = '▎',
        },
        debounce = 300,
        scope = {
          enabled = true,
          highlight = highlight,
          show_end = true,
        },

      }
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    lazy = true,
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      local rainbow_delimiters = require 'rainbow-delimiters'
      require 'rainbow-delimiters.setup' {
        strategy = {
          [''] = rainbow_delimiters.strategy['global'],
          vim = rainbow_delimiters.strategy['local'],
        },
        query = {
          [''] = 'rainbow-delimiters',
          lua = 'rainbow-blocks',
        },
        highlight = {
          "Color1",
          "Color2",
          "Color3",
          "Color4",
          "Color5",
          "Color6",
        },
        blacklist = {  },
      }
    end
  },

  {
    'windwp/nvim-ts-autotag',
    lazy = true,
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      require'nvim-treesitter.configs'.setup {
        autotag = {
          enable = true,
        }
      }
    end
  },

  {
    'nvim-treesitter/nvim-treesitter-context',
    -- commit = "4842abe5bd1a0dc8b67387cc187edbabc40925ba",
    lazy = true,
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      require'treesitter-context'.setup {
        enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
        throttle = true, -- Throttles plugin updates (may improve performance)
        max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
        patterns = {
          -- For all filetypes
          -- Note that setting an entry here replaces all other patterns for this entry.
          -- By setting the 'default' entry below, you can control which nodes you want to
          -- appear in the context window.
          default = {
            'class',
            'function',
            'method',
            'namespace',
            'struct',
            -- 'for', -- These won't appear in the context
            -- 'while',
            -- 'if',
            -- 'switch',
            -- 'case',
          },
          -- Example for a specific filetype.
          -- If a pattern is missing, *open a PR* so everyone can benefit.
          --   rust = {
          --       'impl_item',
          --   },
        },
        mode = 'topline',
      }
      vim.cmd[[hi! link TreesitterContext Context]]
    end
  },

  {
    'm-demare/hlargs.nvim',
    lazy = true,
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    cond = function()
      return vim.g.treesitter_disable ~= true
    end,
    config = function()
      require('hlargs').setup()
    end
  },

  -- cd to project root
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup {
        silent_chdir = true,
        manual_mode = false,
        patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc", "pom.xml" },
        detection_methods = { "pattern", "lsp" },
        ignore_lsp = {"clangd"},
        exclude_dirs = {'~'},
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }

      require('telescope').load_extension('projects')
    end
  },

  {
    'stevearc/aerial.nvim',
    lazy = true,
    keys = "<leader>v",
    cond = vim.g.vscode == nil,
    config = function()
      vim.keymap.set('n', '<leader>v', '<cmd>AerialToggle!<CR>', { silent = true })
      local status_ok, telescope = pcall(require, "telescope")
      if status_ok then
        telescope.load_extension('aerial')
      end
      require("aerial").setup({
        backends = {"lsp", "treesitter", "markdown"},

        filter_kind = false,
        guides = {
          -- When the child item has a sibling below it
          mid_item = "├─",
          -- When the child item is the last in the list
          last_item = "└─",
          -- When there are nested child guides to the right
          nested_top = "│ ",
          -- Raw indentation
          whitespace = "  ",
        },
        icons = kind_icons_list,
        layout = {
          max_width = 200,
        },
        lsp = {
          diagnostics_trigger_update = false,
        },
        disable_max_lines = -1,
      })
      -- winbar
      local aerial = require('aerial')

      -- Format the list representing the symbol path
      -- Grab it from https://github.com/stevearc/aerial.nvim/blob/master/lua/lualine/components/aerial.lua
      local function format_symbols(symbols, depth, separator, icons_enabled)
        local parts = {}
        depth = depth or #symbols

        if depth > 0 then
          symbols = { unpack(symbols, 1, depth) }
        else
          symbols = { unpack(symbols, #symbols + 1 + depth) }
        end

        for _, symbol in ipairs(symbols) do
          if icons_enabled then
            table.insert(parts, string.format("%s%s", symbol.icon, symbol.name))
          else
            table.insert(parts, symbol.name)
          end
        end

        return table.concat(parts, separator)
      end

      winbar_aerial = function()
        -- Get a list representing the symbol path by aerial.get_location (see
        -- https://github.com/stevearc/aerial.nvim/blob/master/lua/aerial/init.lua#L127),
        -- and format the list to get the symbol path.
        -- Grab it from
        -- https://github.com/stevearc/aerial.nvim/blob/master/lua/lualine/components/aerial.lua#L89

        local symbols = aerial.get_location(true)
        local symbol_path = format_symbols(symbols, nil, ' > ', true)

        if symbol_path ~= "" then
          return "> " .. symbol_path
        end
        return ""
      end

      filename_with_icon = function()
        local winbar_aerial_ft_exclude = {}

        for _, ft in ipairs(winbar_aerial_ft_exclude) do
          if vim.o.filetype == ft then
            return ""
          end
        end

        -- nvim-tree
        if vim.o.filetype == "NvimTree" then
          return vim.api.nvim_exec("pwd", true)
        end

        local path_with_slash = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
        path_with_slash = vim.split(path_with_slash, "/", {plain=true})
        local icon = require("nvim-web-devicons").get_icon_by_filetype(vim.o.filetype)
        local file_with_arrow

        if #path_with_slash == 1 then
          if icon ~= nil then
            file_with_arrow = icon .. " " .. path_with_slash[1]
          else
            file_with_arrow = path_with_slash[1]
          end
          return file_with_arrow
        end

        file_with_arrow = path_with_slash[1]
        for i, iter in pairs(path_with_slash) do
          if i ~= 1 and i ~= #path_with_slash then
            file_with_arrow = file_with_arrow .. " > " .. iter
          elseif i == #path_with_slash then
            if icon ~= nil then
              file_with_arrow = file_with_arrow .. " > " .. icon .. " " .. iter
            else
              file_with_arrow = file_with_arrow .. " > " .. iter
            end
          end
        end
        return file_with_arrow
      end

      vim.cmd[[ hi link AerialWinHLFields Constant ]]
      vim.cmd[[ hi link AerialWinHLFile FileName ]]
      -- vim.o.winbar = " %#AerialWinHLFile#%{%v:lua.filename_with_icon()%} %#AerialWinHLFields#%{%v:lua.winbar_aerial()%}"

    end
  },

  {
    "Bekaboo/dropbar.nvim",
    config = function()
      local no_bold = {}
      for key, _ in pairs(kind_icons_list) do
        table.insert(no_bold, "DropBarKind" .. key)
      end
      for _, hl in ipairs(no_bold) do
        vim.api.nvim_set_hl(0, hl, { bold = false })
      end
      vim.api.nvim_set_hl(0, "DropBarKindFile", { bold = true })
      vim.api.nvim_set_hl(0, "DropBarKindFolder", { bold = true })

      vim.api.nvim_set_hl(0, "DropBarIconUIPickPivot", { link = "Visual" })
      vim.keymap.set("n", "<leader>V", require('dropbar.api').pick, { noremap = true, silent = true })

      local api = require('dropbar.api')
      require('dropbar').setup {
        icons = {
          ui = {
            bar = {
              separator = "  ",
            }
          }
        },
        menu = {
          keymaps = {
            ['<Esc>'] = function()
              local menu = api.get_current_dropbar_menu()
              menu:close()
            end,
            ['h'] = function()
              local menu = api.get_current_dropbar_menu()
              if menu.prev_menu then
                menu:close()
              end
            end,
            ['l'] = function()
              local menu = require('dropbar.api').get_current_dropbar_menu()
              local cursor = vim.api.nvim_win_get_cursor(menu.win)
              local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
              if component and component.children then
                menu:click_on(component, nil, 1, 'l')
              end
            end
          },
          win_configs = {
            border = "single",
          }
        }
      }
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"fugitiveblame"},
        callback = function()
          vim.o.winbar = "Git blame"
        end
      })
    end
  },

-- git signs
  {
    'lewis6991/gitsigns.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim'
    },
    config = function()
      require('gitsigns').setup{
        signs = {
          add          = {hl = 'GitSignsAdd'   , text = '│', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn'},
          change       = {hl = 'GitSignsChange', text = '│', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
          delete       = {hl = 'GitSignsDelete', text = '_', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
          topdelete    = {hl = 'GitSignsDelete', text = '‾', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
          changedelete = {hl = 'GitSignsChange', text = '~', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
        },
        signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
        numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
        linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
        word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir = {
          interval = 1000,
          follow_files = true
        },
        attach_to_untracked = true,
        current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
          virt_text_priority = 0,
          delay = 250,
          ignore_whitespace = false,
        },
        current_line_blame_formatter = '      <author>, <author_time:%R> - <summary>',
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil, -- Use default
        max_file_length = 40000,
        preview_config = {
          -- Options passed to nvim_open_win
          border = 'single',
          style = 'minimal',
          relative = 'cursor',
          row = 0,
          col = 1
        },
        yadm = {
          enable = false
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']g', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function()
              if vim.g.vscode then
                vscode_next_hunk()
              else
                gs.next_hunk()
              end
            end)
            return '<Ignore>'
          end, {expr=true})

          map('n', '[g', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function()
              if vim.g.vscode then
                vscode_prev_hunk()
              else
                gs.prev_hunk()
              end
            end)
            return '<Ignore>'
          end, {expr=true})

          -- Actions
          map({'n', 'v'}, '<leader>ga', ':Gitsigns stage_hunk<CR>')
          map('n', '<leader>gA', gs.stage_buffer)
          map('n', '<leader>gu', gs.undo_stage_hunk)
          map({'n', 'v'}, '<leader>gr', ':Gitsigns reset_hunk<CR>')
          map('n', '<leader>gR', '<cmd>Gitsigns reset_buffer<CR>')
          map('n', '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>')
          map('n', '<leader>gm', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>')
          map('n', '<leader>gb', '<cmd>Gitsigns toggle_current_line_blame<CR>')
          map('n', '<leader>gd', '<cmd>Gitsigns toggle_deleted<CR>')

          -- Text object
          map('o', 'ih', ':<C-U>Gitsigns select_hunk<CR>')
          map('x', 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        end
      }
    end
  },

  {
    "akinsho/git-conflict.nvim",
    config = function()
      require('git-conflict').setup {
        default_mappings = false
      }
      vim.keymap.set('n', "]x", "<cmd>GitConflictNextConflict<cr>")
      vim.keymap.set('n', "[x", "<cmd>GitConflictPrevConflict<cr>")

    end
  },
  {
    "sindrets/diffview.nvim",
    lazy = true,
    cmd = {"DiffviewOpen", "DiffviewFileHistory"},
    opts = {
      view = {
        merge_tool = {
          layout = "diff3_mixed"
        }
      }
    }
  },

  -- colorizer
  {
    'NvChad/nvim-colorizer.lua',
    config = function()
      require'colorizer'.setup()
    end
  },

  {
    'akinsho/bufferline.nvim',
    config = function()
      require("bufferline").setup {
        options = {
          -- separator_style = "slant",
          diagnostics = "nvim_lsp",
          max_name_length = 100,
          -- name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
          --   -- remove extension from markdown files for example
          --   if buf.bufnr == vim.fn.bufnr() then
          --     return vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
          --   else
          --     return buf.name
          --   end
          -- end,
          diagnostics_indicator = function(count, level, diagnostics_dict, context)
            local s = " "
            for e, n in pairs(diagnostics_dict) do
              local sym = e == "error" and "󰅚 "
              or (e == "warning" and "  " or " " )
              s = s .. n .. sym
            end
            return s
          end,
        },
        highlights = {
          indicator_selected = {
              fg = {
                attribute = "fg",
                highlight = "Keyword"
              }
          },
          separator = {
            fg = {
              attribute = "fg",
              highlight = "SpecialKey"
            }
          }
        }
      }

      vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", {link = "Keyword"})
      vim.api.nvim_set_hl(0, "BufferLineSeparator", {link = "SpecialKey"})

      -- use alt + number to go to buffer
      for i = 1, 9 do
        vim.keymap.set("n", "<M-" .. i .. ">",  function() require("bufferline").go_to(i, true) end, { noremap = true, silent = true })
      end
    end
  },

  {
    'Vonr/align.nvim',
    lazy = true,
    keys = {{'al', mode = 'x'}},
    cmd = "Align",
    config = function()
      local NS = { noremap = true, silent = true }
      vim.keymap.set('x', 'al', function() require'align'.align_to_string({preview = true, regex = true}) end, NS)
      vim.api.nvim_create_user_command("Align", function(opts)
        _, sr, sc, _ = unpack(vim.fn.getpos('v') or {0, 0, 0, 0})
        _, er, ec, _ = unpack(vim.fn.getcurpos())
        require'align'.align(opts.args, {
          preview = true,
          regex = true,
          marks = {sr = opts.line1, sc = sc, er = opts.line2, ec = ec}
        })
      end, {nargs = 1, range = true})
    end
  },

  {
    -- enhanced <c-a> and <c-x>
    'monaqa/dial.nvim',
    keys = {
      {'g<C-a>', mode = 'v'},
      {'g<C-x>', mode = 'v'},
      {'<C-a>'},
      {'<C-x>'}
    },
    config = function()
      vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), {noremap = true})
      vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), {noremap = true})
      vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), {noremap = true})
      vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), {noremap = true})
      vim.keymap.set("v", "g<C-a>",require("dial.map").inc_gvisual(), {noremap = true})
      vim.keymap.set("v", "g<C-x>",require("dial.map").dec_gvisual(), {noremap = true})

      local augend = require("dial.augend")
      require("dial.config").augends:register_group{
        -- default augends used when no group name is specified
        default = {
          augend.integer.alias.decimal_int,   -- nonnegative decimal number (0, 1, 2, 3, ...)
          augend.integer.alias.hex,       -- nonnegative hex number  (0x01, 0x1a1f, etc.)
          augend.integer.alias.binary,
          augend.integer.alias.octal,
          augend.constant.alias.bool,
          augend.constant.new {
            elements = { "True", "False" },
          },
          augend.constant.new {
            elements = { "yes", "no" },
          },
          augend.semver.alias.semver,
          augend.date.alias["%Y/%m/%d"],  -- date (2022/02/19, etc.)
        },
      }
    end
  },

  {
    -- provide ui for lsp
    'stevearc/dressing.nvim',
  },

  {
    'smjonas/inc-rename.nvim',
    keys = "<leader>rn",
    config = function()
      require("inc_rename").setup({
        input_buffer_type = "dressing",
      })
      vim.keymap.set("n", "<leader>rn", function()
        return ":IncRename " .. vim.fn.expand("<cword>")
      end, { expr = true })
    end
  },

  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'kyazdani42/nvim-web-devicons' },
    config = function()
      local custom_auto = require'lualine.themes.auto'
      if vim.g.colors_name == 'ghdark' then
        custom_auto.normal.a.fg = "#C4CBD7"
        custom_auto.normal.b.fg = "#9CA5B3"
        custom_auto.normal.c.bg = "#21262D"
        custom_auto.inactive = {
          a = { fg = '#c6c6c6', bg = '#080808' },
          b = { fg = '#c6c6c6', bg = '#080808' },
          c = { fg = '#c6c6c6', bg = '#080808' },
        }
      end
      local function get_venv()
        local venv_name = os.getenv("VIRTUAL_ENV")
        if venv_name ~= nil then
          local venv_short_name = vim.fn.fnamemodify(venv_name, ":t")
          if venv_short_name == "venv" then
            venv_short_name = vim.fn.fnamemodify(venv_name, ":h:t")
          end
          return "(" .. venv_short_name .. ")"
        else
          return ""
        end
      end
      -- lsp info, from https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua
      --
      local lsp_click = function()
        if vim.o.ft == "python" then
          vim.cmd.VenvSelect()
        end
      end
      local lsp_info =  {
        -- Lsp server name .
        function()
          local no_lsp = ''
          local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
          local clients = vim.lsp.get_active_clients()
          if next(clients) == nil then
            return no_lsp
          end
          local client_names = {}
          for _, client in ipairs(clients) do
            local filetypes = client.config.filetypes
            if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
              table.insert(client_names, client.name)
            end
          end
          if next(client_names) == nil then
            return no_lsp
          else
            -- remove duplicate items
            local seen = {}
            local unique = {}
            for _, v in ipairs(client_names) do
              if not seen[v] then
                if v:match("py.*") then
                  v = v .. get_venv()
                end
                table.insert(unique, v)
                seen[v] = true
              end
            end
            return table.concat(unique, ', ')
          end
        end,
        icon = ' ',
        color = {gui = 'bold'},
        on_click = lsp_click
      }

      vim.api.nvim_create_autocmd({"InsertEnter"}, {
        callback = function()
          if vim.g.copilot_initialized == 1 then
            return
          end
          for k, v in pairs(vim.g.copilot_filetypes) do
            if k == vim.bo.filetype and v == false then
              return
            end
          end
          if vim.g.no_load_copilot ~= 1 then
            vim.g.copilot_initialized = 1
          end
        end,
      })

      local copilot = function()
        if vim.g.copilot_initialized == 1 then
          if vim.api.nvim_eval("copilot#Enabled()") == 1 then
            return ' '
          else
            return '󱃓 '
          end
        else
          return '󱃓 '
        end
      end

      local function gtagsHandler()
        if vim.g.gutentags_load == 1 then
          if vim.api.nvim_eval("gutentags#statusline()") == "" then
            return ''
          else
            return "Tags Indexing..."
          end
        else
          return ''
        end
      end

      local function auto_session_name()
        local status_ok, lib = pcall(require, 'auto-session-library')
        if status_ok then
          return lib.current_session_name()
        else
          return ''
        end
      end

      local nix_dev = {
        function()
          -- get $NIX_DEV
          local nix_dev = vim.env.NIX_DEV
          if nix_dev == nil then
            return ''
          end
          return nix_dev
        end,
        icon = ' ',
        color = {gui = 'bold', fg = "#58A6FF"}
      }

      local function shiftwidth()
        local sw = vim.fn.shiftwidth()
        return "sw:" .. sw
      end

      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = custom_auto,
          component_separators = { left = ')', right = '('},
          section_separators = { left = '', right = ''},
          disabled_filetypes = {},
          always_divide_middle = true,
        },
        sections = {
          lualine_a = {{'filename', path = 0}},
          lualine_b = {'branch', 'diff', {
            'diagnostics',
            symbols = {error = ' ', warn = ' ', info = ' ', hint = ' '},
          }},
          lualine_c = {lsp_info, gtagsHandler},
          lualine_x = {auto_session_name,  nix_dev},
          lualine_y = { 'fileformat', 'filetype', copilot},
          lualine_z = {shiftwidth, '%l/%L,%c', 'encoding'}
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {'filename'},
          lualine_x = {'location'},
          lualine_y = {},
          lualine_z = {}
        },
        tabline = {},
        extensions = {'quickfix', 'aerial', 'fugitive', 'nvim-tree', }
      }
    end
  },

  {
    'kevinhwang91/rnvimr',
    lazy = true,
    cond = vim.g.vscode == nil,
    keys = "<leader>ra",
    cmd = "RnvimrToggle",
    config = function()
      vim.keymap.set('n', '<leader>ra', '<cmd>RnvimrToggle<CR>', {silent = true})
      vim.g.rnvimr_enable_picker = 1
    end
  },

  -- highlight cursor words via lsp
  {
    'RRethy/vim-illuminate',
    lazy = true,
    config = function()
      require('illuminate').configure({
        -- providers: provider used to get references in the buffer, ordered by priority
        providers = {
          'lsp',
          -- 'treesitter', -- treesitter is too slow!
          'regex',
        },
        -- delay: delay in milliseconds
        delay = 100,
        -- filetype_overrides: filetype specific overrides.
        -- The keys are strings to represent the filetype while the values are tables that
        -- supports the same keys passed to .configure except for filetypes_denylist and filetypes_allowlist
        filetype_overrides = {},
        -- filetypes_denylist: filetypes to not illuminate, this overrides filetypes_allowlist
        filetypes_denylist = {
          'dirvish',
          'fugitive',
        },
        -- filetypes_allowlist: filetypes to illuminate, this is overriden by filetypes_denylist
        filetypes_allowlist = {},
        -- modes_denylist: modes to not illuminate, this overrides modes_allowlist
        modes_denylist = {},
        -- modes_allowlist: modes to illuminate, this is overriden by modes_denylist
        modes_allowlist = {},
        -- providers_regex_syntax_denylist: syntax to not illuminate, this overrides providers_regex_syntax_allowlist
        -- Only applies to the 'regex' provider
        -- Use :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
        providers_regex_syntax_denylist = {},
        -- providers_regex_syntax_allowlist: syntax to illuminate, this is overriden by providers_regex_syntax_denylist
        -- Only applies to the 'regex' provider
        -- Use :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
        providers_regex_syntax_allowlist = {},
        -- under_cursor: whether or not to illuminate under the cursor
        under_cursor = true,
      })

      vim.api.nvim_set_hl(0, "IlluminatedWordText", {link = "UnderCursorText"})
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", {link = "UnderCursorRead"})
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", {link = "UnderCursorWrite"})
    end
  },

  {
    'kyazdani42/nvim-tree.lua',
    lazy = true,
    keys = "<leader>n",
    dependencies = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icon
    },
    config = function()
      vim.keymap.set('n', '<leader>n', '<cmd>NvimTreeFindFileToggle<CR>', {silent = true})
      local api = require('nvim-tree.api')

      local on_attach = function(bufnr)

        local opts = function(desc)
          return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        vim.keymap.set('n', '<C-]>', api.tree.change_root_to_node,          opts('CD'))
        vim.keymap.set('n', '<C-e>', api.node.open.replace_tree_buffer,     opts('Open: In Place'))
        vim.keymap.set('n', '<C-k>', api.node.show_info_popup,              opts('Info'))
        vim.keymap.set('n', '<C-r>', api.fs.rename_sub,                     opts('Rename: Omit Filename'))
        vim.keymap.set('n', '<C-t>', api.node.open.tab,                     opts('Open: New Tab'))
        vim.keymap.set('n', '<C-v>', api.node.open.vertical,                opts('Open: Vertical Split'))
        vim.keymap.set('n', '<C-x>', api.node.open.horizontal,              opts('Open: Horizontal Split'))
        vim.keymap.set('n', '<BS>',  api.node.navigate.parent_close,        opts('Close Directory'))
        vim.keymap.set('n', '<CR>',  api.node.open.edit,                    opts('Open'))
        vim.keymap.set('n', '<Tab>', api.node.open.preview,                 opts('Open Preview'))
        vim.keymap.set('n', '>',     api.node.navigate.sibling.next,        opts('Next Sibling'))
        vim.keymap.set('n', '<',     api.node.navigate.sibling.prev,        opts('Previous Sibling'))
        vim.keymap.set('n', '.',     api.node.run.cmd,                      opts('Run Command'))
        vim.keymap.set('n', '-',     api.tree.change_root_to_parent,        opts('Up'))
        vim.keymap.set('n', 'a',     api.fs.create,                         opts('Create'))
        vim.keymap.set('n', 'bmv',   api.marks.bulk.move,                   opts('Move Bookmarked'))
        vim.keymap.set('n', 'B',     api.tree.toggle_no_buffer_filter,      opts('Toggle No Buffer'))
        vim.keymap.set('n', 'c',     api.fs.copy.node,                      opts('Copy'))
        vim.keymap.set('n', 'C',     api.tree.toggle_git_clean_filter,      opts('Toggle Git Clean'))
        vim.keymap.set('n', '[c',    api.node.navigate.git.prev,            opts('Prev Git'))
        vim.keymap.set('n', ']c',    api.node.navigate.git.next,            opts('Next Git'))
        vim.keymap.set('n', 'd',     api.fs.remove,                         opts('Delete'))
        vim.keymap.set('n', 'D',     api.fs.trash,                          opts('Trash'))
        vim.keymap.set('n', 'E',     api.tree.expand_all,                   opts('Expand All'))
        vim.keymap.set('n', 'e',     api.fs.rename_basename,                opts('Rename: Basename'))
        vim.keymap.set('n', ']e',    api.node.navigate.diagnostics.next,    opts('Next Diagnostic'))
        vim.keymap.set('n', '[e',    api.node.navigate.diagnostics.prev,    opts('Prev Diagnostic'))
        vim.keymap.set('n', 'F',     api.live_filter.clear,                 opts('Clean Filter'))
        vim.keymap.set('n', 'f',     api.live_filter.start,                 opts('Filter'))
        vim.keymap.set('n', 'g?',    api.tree.toggle_help,                  opts('Help'))
        vim.keymap.set('n', 'gy',    api.fs.copy.absolute_path,             opts('Copy Absolute Path'))
        vim.keymap.set('n', '<c-h>', api.tree.toggle_hidden_filter,         opts('Toggle Dotfiles'))
        vim.keymap.set('n', 'I',     api.tree.toggle_gitignore_filter,      opts('Toggle Git Ignore'))
        vim.keymap.set('n', 'm',     api.marks.toggle,                      opts('Toggle Bookmark'))
        vim.keymap.set('n', 'o',     api.node.open.edit,                    opts('Open'))
        vim.keymap.set('n', 'O',     api.node.open.no_window_picker,        opts('Open: No Window Picker'))
        vim.keymap.set('n', 'p',     api.fs.paste,                          opts('Paste'))
        vim.keymap.set('n', 'P',     api.node.navigate.parent,              opts('Parent Directory'))
        vim.keymap.set('n', 'q',     api.tree.close,                        opts('Close'))
        vim.keymap.set('n', 'r',     api.fs.rename,                         opts('Rename'))
        vim.keymap.set('n', 'R',     api.tree.reload,                       opts('Refresh'))
        vim.keymap.set('n', 's',     api.node.run.system,                   opts('Run System'))
        vim.keymap.set('n', 'S',     api.tree.search_node,                  opts('Search'))
        vim.keymap.set('n', 'U',     api.tree.toggle_custom_filter,         opts('Toggle Hidden'))
        vim.keymap.set('n', 'W',     api.tree.collapse_all,                 opts('Collapse'))
        vim.keymap.set('n', 'x',     api.fs.cut,                            opts('Cut'))
        vim.keymap.set('n', 'y',     api.fs.copy.filename,                  opts('Copy Name'))
        vim.keymap.set('n', 'Y',     api.fs.copy.relative_path,             opts('Copy Relative Path'))
        vim.keymap.set('n', '<2-LeftMouse>',  api.node.open.edit,           opts('Open'))
        vim.keymap.set('n', '<2-RightMouse>', api.tree.change_root_to_node, opts('CD'))
        vim.keymap.set('n', '=', api.tree.change_root_to_node, opts('CD'))
        vim.keymap.set('n', '<leader>', api.node.open.edit, opts('Open'))

      end

      require'nvim-tree'.setup {
        on_attach = on_attach,
        disable_netrw = true,
        diagnostics = {
          enable = true,
        },
        renderer = {
          highlight_git = true,
          group_empty = true,
        },
        git = {
          ignore = false,
        }
      }
    end
  },

  {
    'famiu/bufdelete.nvim',
    lazy = true,
    keys = '<leader>x',
    cond = vim.g.vscode == nil,
    config = function()
      vim.keymap.set('n', '<leader>x', '<cmd>Bdelete!<CR>', {silent = true})
    end
  },

  {
    'nvim-telescope/telescope-fzf-native.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    build = 'make',
    config = function()
      require('telescope').setup {
        extensions = {
          fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
          }
        }
      }
      -- To get fzf loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      require('telescope').load_extension('fzf')
    end
  },

  {
    'jonarrien/telescope-cmdline.nvim',
    config = function()
      require("telescope").load_extension('cmdline')
      require('cmdline.config').values.picker.layout_config = nil
    end
  },

  {
    'MattesGroeger/vim-bookmarks',
    lazy = true,
    keys = {
      '<leader>mm',
      '<leader>mi',
      '<leader>mn',
      '<leader>mp',
      '<leader>ma',
      '<leader>mc',
    },
    init = function()
      vim.g.bookmark_no_default_key_mappings = 1
    end,
    config = function()
      vim.g.bookmark_sign = ''
      vim.keymap.set('n', '<leader>mm', '<cmd>BookmarkToggle<CR>', {silent = true})
      vim.keymap.set('n', '<leader>mi', '<cmd>BookmarkAnnotate<CR>', {silent = true})
      vim.keymap.set('n', '<leader>mn', '<cmd>BookmarkNext<CR>', {silent = true})
      vim.keymap.set('n', '<leader>mp', '<cmd>BookmarkPrev<CR>', {silent = true})
      vim.keymap.set('n', '<leader>ma', '<cmd>BookmarkShowAll<CR>', {silent = true})
      vim.keymap.set('n', '<leader>mc', '<cmd>BookmarkClear<CR>', {silent = true})
    end
  },

  {
    'tom-anders/telescope-vim-bookmarks.nvim',
    dependencies = {
      'MattesGroeger/vim-bookmarks'
    },
    config = function()
      require('telescope').load_extension('vim_bookmarks')
    end
  },

  {
    'rmagatti/auto-session',
    init = function()
      if #vim.fn.argv() == 1 and vim.fn.isdirectory(vim.fn.argv()[1]) == 1 then
        vim.cmd.cd(vim.fn.argv()[1])
        local res = require('auto-session').RestoreSession()
        if res then
          vim.cmd("bdelete " .. vim.fn.getcwd())
        end
      end
    end,
    config = function()
      local restore_last = false
      if vim.g.neovide ~= nil
        and #vim.fn.argv() == 0
        and vim.g.remote_ui == nil then
        restore_last = true
        vim.defer_fn(function() -- execute after function exit (setted up)
          require('auto-session').RestoreSession()
        end, 0)
      end
      require('auto-session').setup {
        log_level = 'error',
        auto_session_suppress_dirs = {'~/', '~/Downloads', '~/Documents'},
        auto_session_create_enabled = false,
        auto_session_enable_last_session = restore_last,
        auto_save_enabled = true,
        auto_restore_enabled = true,
        post_restore_cmds = {'silent !kill -s SIGWINCH $PPID'},
        pre_restore = 'let g:not_start_alpha = true',
        pre_save_cmds = {
          function()
            pcall(vim.cmd, "NvimTreeClose")
          end
        },
      }
    end
  },

  {
    'goolord/alpha-nvim',
    dependencies = { 'rmagatti/auto-session' },
    cond = function()
      return vim.g.not_start_alpha ~= true
          and #vim.fn.argv() == 0
          and vim.g.started_by_firenvim == nil
    end,
    config = function ()
      -- TODO: slow under WSL, because of PATH
      local alpha = require'alpha'
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[ ██\   ██\                    ██\    ██\ ██████\ ██\      ██\  ]],
        [[ ███\  ██ |                   ██ |   ██ |\_██  _|███\    ███ | ]],
        [[ ████\ ██ | ██████\   ██████\ ██ |   ██ |  ██ |  ████\  ████ | ]],
        [[ ██ ██\██ |██  __██\ ██  __██\\██\  ██  |  ██ |  ██\██\██ ██ | ]],
        [[ ██ \████ |████████ |██ /  ██ |\██\██  /   ██ |  ██ \███  ██ | ]],
        [[ ██ |\███ |██   ____|██ |  ██ | \███  /    ██ |  ██ |\█  /██ | ]],
        [[ ██ | \██ |\███████\ \██████  |  \█  /   ██████\ ██ | \_/ ██ | ]],
        [[ \__|  \__| \_______| \______/    \_/    \______|\__|     \__| ]],
      }

      -- https://github.com/AdamWhittingham/vim-config/blob/nvim/lua/config/startup_screen.lua
      local nvim_web_devicons = require "nvim-web-devicons"
      path = require"plenary.path"
      local function get_extension(fn)
        local match = fn:match("^.+(%..+)$")
        local ext = ""
        if match ~= nil then
          ext = match:sub(2)
        end
        return ext
      end

      local function icon(fn)
        local nwd = require("nvim-web-devicons")
        local ext = get_extension(fn)
        return nwd.get_icon(fn, ext, { default = true })
      end

      local function file_button(fn, sc, short_fn)
        short_fn = short_fn or fn
        local ico_txt
        local fb_hl = {}

        local ico, hl = icon(fn)
        local hl_option_type = type(nvim_web_devicons.highlight)
        if hl_option_type == "boolean" then
          if hl and nvim_web_devicons.highlight then
            table.insert(fb_hl, { hl, 0, 1 })
          end
        end
        if hl_option_type == "string" then
          table.insert(fb_hl, { nvim_web_devicons.highlight, 0, 1 })
        end
        ico_txt = ico .. "  "

        local file_button_el = dashboard.button(sc, ico_txt .. short_fn, "<cmd>e " .. fn .. " <CR>")

        -- change width
        file_button_el.opts.width = 75

        local fn_start = short_fn:match(".*/")
        if fn_start ~= nil then
          table.insert(fb_hl, { "Comment", #ico_txt - 2, #fn_start + #ico_txt - 2 })
        end
        file_button_el.opts.hl = fb_hl
        return file_button_el
      end

      local default_mru_ignore = { "gitcommit" }

      local mru_opts = {
        ignore = function(path, ext)
          return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
        end,
      }
      local function mru(start, cwd, items_number, opts)
        opts = opts or mru_opts
        items_number = items_number or 9

        local oldfiles = {}
        for _, v in pairs(vim.v.oldfiles) do
          if #oldfiles == items_number then
            break
          end
          local cwd_cond
          if not cwd then
            cwd_cond = true
          else
            cwd_cond = vim.startswith(v, cwd)
          end
          local ignore = (opts.ignore and opts.ignore(v, get_extension(v))) or false
          if (vim.fn.filereadable(v) == 1) and cwd_cond and not ignore then
            oldfiles[#oldfiles + 1] = v
          end
        end

        local special_shortcuts = {'a', 's', 'd' }
        local target_width = 35

        local tbl = {}
        for i, fn in ipairs(oldfiles) do
          local short_fn
          if cwd then
            short_fn = vim.fn.fnamemodify(fn, ":.")
          else
            short_fn = vim.fn.fnamemodify(fn, ":~")
          end

          if(#short_fn > target_width) then
            short_fn = path.new(short_fn):shorten(1, {-2, -1})
            if(#short_fn > target_width) then
              short_fn = path.new(short_fn):shorten(1, {-1})
            end
          end

          local shortcut = ""
          if i <= #special_shortcuts then
            shortcut = special_shortcuts[i]
          else
            shortcut = tostring(i + start - 1 - #special_shortcuts)
          end

          local file_button_el = file_button(fn, shortcut, short_fn)
          tbl[i] = file_button_el
        end
        return {
          type = "group",
          val = tbl,
          opts = {spacing  = 1},
        }
      end
      local section_mru = {
        type = "group",
        val = {
          {
            type = "text",
            val = "Recent Files",
            opts = {
              hl = "SpecialComment",
              shrink_margin = false,
              position = "center",
            },
          },
          {
            type = "group",
            val = function()
              return { mru(1, cdir, 15) }
            end,
            opts = { shrink_margin = false },
          },
        },
        opts = {
          spacing = 1,
        },
      }

      dashboard.section.buttons.val = {
        dashboard.button("e", "  New file", "<cmd>ene <CR>"),
        dashboard.button("l", "󰁯  Load session", "<cmd> SessionRestore <cr>"),
        dashboard.button("y", "  Open file manager", "<cmd>YaziToggle <cr>"),
        dashboard.button("z", "  Z jump", "<cmd>ZjumpToggle <cr>"),
        dashboard.button("f", "󰍉  Find file", "<cmd>Telescope find_files<CR>"),
        dashboard.button("h", "󱔗  Recently opened files", "<cmd> Telescope oldfiles <CR>"),
        dashboard.button("g", "󰈬  Find word","<cmd>Telescope live_grep<CR>"),
        dashboard.button("m", "󰃃  Jump to bookmarks", "<cmd>Telescope vim_bookmarks<cr>"),
        -- dashboard.button("u", "  Update plugins" , ":Lazy sync<CR>"),
        dashboard.button("c", "  Open Config" , "<cmd>e ~/dotfiles/.vimrc<cr><cmd>e ~/dotfiles/.nvimrc.lua<cr>"),
        dashboard.button("q", "󰅚  Quit" , ":qa<CR>"),
      }

      for _, v in pairs(dashboard.section.buttons.val) do
        v.opts.width = 75
      end

      local hot_keys = {
        type = "text",
        val = "Hot Keys",
        opts = {
          hl = "SpecialComment",
          shrink_margin = false,
          position = "center",
        },
      }

      dashboard.config.layout = {
        { type = "padding", val = 2 },
        dashboard.section.header,
        { type = "padding", val = 1 },
        hot_keys,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        section_mru,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }

      alpha.setup(dashboard.config)

    end
  },

  {
    'tversteeg/registers.nvim',
    keys = {
      { '"',     mode = { 'v', 'n' } },
      { '<C-r>', mode = { 'i' } }
    },
    cond = vim.g.vscode == nil,
    opts = {
      window = {
        border = "single"
      }
    }
  },

  {
    'numToStr/Comment.nvim',
    keys = {
      {"<c-_>", mode = 'v'},
      {"<c-s-_>", mode = 'v'},
      {"<c-_>", mode = 'n'},
      {"<c-s-_>", mode = 'n'},
      {"<c-/>", mode = 'v'},
      {"<c-s-/>", mode = 'v'},
      {"<c-/>", mode = 'n'},
      {"<c-s-/>", mode = 'n'},
    },
    cond = vim.g.vscode == nil,
    config = function()
      local bindkey
      if os.getenv("TMUX") ~= nil and vim.g.neovide == nil then
        bindkey = {
          line = '<c-_>',
          block = '<c-s-_>',
        }
      else
        bindkey = {
          line = '<c-/>',
          block = '<c-s-/>',
        }
      end
      require('Comment').setup {
        ---Add a space b/w comment and the line
        padding = true,
        ---Whether the cursor should stay at its position
        sticky = true,
        ---Lines to be ignored while (un)comment
        ignore = nil,
        toggler = bindkey,
        opleader = bindkey,
        mappings = {
          basic = true,
          extra = true,
          extended = false,
        },
        ---Function to call before (un)comment
        pre_hook = nil,
        ---Function to call after (un)comment
        post_hook = function(ctx)
          -- execute if ctx.cmotion == 3,4,5
          if ctx.cmotion > 2 then
            if vim.g.plugins_loaded then
              vim.cmd[[ normal gv ]]
            else
              vim.cmd[[ normal gvh ]]
            end
          end
        end,
      }

      local api = require('Comment.api')
      vim.api.nvim_create_user_command("ToggleComment", api.toggle.linewise.current, { nargs = 0 })
      vim.api.nvim_create_user_command("ToggleBlockComment", api.toggle.blockwise.current, { nargs = 0 })
    end
  },

  {
    "folke/trouble.nvim",
    dependencies = {"kyazdani42/nvim-web-devicons"},
    config = function()
      require("trouble").setup {
        action_keys = {
          -- key mappings for actions in the trouble list
          -- map to {} to remove a mapping, for example:
          -- close = {},
          close = "q", -- close the list
          cancel = "<esc>", -- cancel the preview and get back to your last window / buffer / cursor
          refresh = "r", -- manually refresh
          jump = {"<cr>", "<tab>"}, -- jump to the diagnostic or open / close folds
          open_split = { "<c-x>" }, -- open buffer in new split
          open_vsplit = { "<c-v>" }, -- open buffer in new vsplit
          open_tab = { "<c-t>" }, -- open buffer in new tab
          jump_close = {"o"}, -- jump to the diagnostic and close the list
          toggle_mode = "m", -- toggle between "workspace" and "document" diagnostics mode
          toggle_preview = "P", -- toggle auto_preview
          preview = "p", -- preview the diagnostic location
          hover = {},
          close_folds = {"zC"}, -- close all folds
          open_folds = {"zO"}, -- open all folds
          toggle_fold = {"zc", "zo"}, -- toggle fold of current file
        },
      }
    end
  },

  {
    'smoka7/hop.nvim',
    lazy = true,
    keys = {
      {"<leader>w", mode = { "n", "v" }},
      {"<leader>l", mode = { "n", "v" }},
    },
    config = function()
      require'hop'.setup()
      vim.keymap.set('n', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      vim.keymap.set('v', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      -- vim.keymap.set('n', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
      -- vim.keymap.set('v', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
      vim.keymap.set('n', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
      vim.keymap.set('v', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
    end
  },

  {
    "folke/flash.nvim",
    opts = {},
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
      { "<leader><CR>", mode = { "n", "o", "x" }, function() require("nvim-treesitter"); require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("nvim-treesitter"); require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      { "f", "F", "t", "T"},
    },
    config = function()
      local hls = {
        -- FlashBackdrop = { fg = "#545c7e" },
        FlashCurrent = { bg = "#ff966c", fg = "#1b1d2b" },
        FlashLabel = { bg = "#ff007c", bold = true, fg = "#c8d3f5" },
        FlashMatch = { bg = "#3e68d7", fg = "#c8d3f5" },
      }
      for hl_group, hl in pairs(hls) do
        hl.default = true
        vim.api.nvim_set_hl(0, hl_group, hl)
      end
      require("flash").setup {
        modes = {
          search = {
            enabled = false
          },
          char = {
            jump_labels = true,
            highlight = {
              backdrop = false,
            }
          }
        },
        label = {
          rainbow = {
            enabled = false
          }
        }
      }
    end
  },

  {
    'folke/which-key.nvim',
    config = function()
      require("which-key").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        plugins = {
          registers = false,
        },
        window = {
          border = "single"
        },
        triggers_blacklist = {
          -- compatible with vim-oscyank
          n = { "y" }
        }
      }
    end
  },

  {
    "lewis6991/satellite.nvim",
    config = function()
      require('satellite').setup {
        handlers = {
          cursor = {
            enable = false
          }
        }
      }
    end
  },

  {
    "folke/todo-comments.nvim",
    dependencies = {"nvim-lua/plenary.nvim"},
    config = function()
      require("todo-comments").setup {
        keywords = {
          NOTE = {
            -- color = "green"
          },
        },
        colors = {
          green = { "GitSignsAdd" }
        }
      }
    end
  },

  {
    "rcarriga/nvim-notify",
    config = function()
      local banned_messages = {
        "method textDocument/codeLens is not supported by any of the servers registered for the current buffer",
        "method textDocument/inlayHint is not supported by any of the servers registered for the current buffer",
        "[inlay_hints] LSP error:Invalid offset",
        "LSP[rust_analyzer] rust-analyzer failed to load workspace: Failed to read Cargo metadata from Cargo.toml",
      }

      vim.notify = function (msg, ...)
        for _, banned in ipairs(banned_messages) do
          if string.find(msg, banned, 1, true) then
            return
          end
        end
        if string.find(msg, "signatureHelp", 1, true) then
          print(msg)
          return
        end
        if string.find(msg, "auto-session ERROR: Error restoring session!", 1, true) then
          vim.cmd("normal! zR")
          vim.notify("Auto session corrupted, restored the old", "info", { title = "Auto Session" })
          require('auto-session').SaveSession()
          return
        end
        require("notify")(msg, ...)
      end
    end
  },

  {
    url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    lazy = true,
    config = function()
      require("lsp_lines").setup()
    end,
  },

  {
    -- enable yank through ssh
    'ojroques/nvim-osc52',
    lazy = true,
  },

  {
    'glacambre/firenvim',
    -- Lazy load firenvim
    -- Explanation: https://github.com/folke/lazy.nvim/discussions/463#discussioncomment-4819297
    lazy = not vim.g.started_by_firenvim,
    dependencies = { 'github/copilot.vim', 'neovim/nvim-lspconfig' },
    build = function()
      require("lazy").load({ plugins = "firenvim", wait = true })
      vim.fn["firenvim#install"](0)
    end,
    config = function()
      vim.o.laststatus = 0
      vim.g.firenvim_config = {
        globalSettings = { alt = "all" },
        localSettings = {
          [".*"] = {
            cmdline  = "neovim",
            content  = "text",
            priority = 0,
            selector = "textarea",
            takeover = "never"
          }
        }
      }
    end
  },

  {
    "linux-cultist/venv-selector.nvim",
    dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim", "mfussenegger/nvim-dap-python" },
    cmd = {"VenvSelect", "VenvSelectCached"},
    config = function()
      require("venv-selector").setup({
        -- Your options go here
        -- name = "venv",
        -- auto_refresh = false
      })
    end
  },

  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {{"<leader>j", mode = 'n'}},
    config = function()
      require('treesj').setup {
        use_default_keymaps = false
      }
      vim.keymap.set('n', '<leader>j', require('treesj').toggle, { silent = true })
    end,
  },

  {
    'ldelossa/litee-calltree.nvim',
    cmd = { "IncomingCalls", "OutgoingCalls" },
    dependencies = { 'ldelossa/litee.nvim' },
    config = function()
      -- configure the litee.nvim library 
      require('litee.lib').setup {}
      -- configure litee-calltree.nvim
      require('litee.calltree').setup {
        keymaps = {
          expand = 'o',
          collapse = 'O'
        }
      }
      vim.api.nvim_create_user_command("IncomingCalls", vim.lsp.buf.incoming_calls, { nargs = 0 })
      vim.api.nvim_create_user_command("OutgoingCalls", vim.lsp.buf.outgoing_calls, { nargs = 0 })
      vim.keymap.set('n', '<c-l>', "<cmd>LTClearJumpHL<cr><cmd>nohlsearch<cr>", { silent = true })
    end
  },

  {
    'levouh/tint.nvim',
    lazy = false,
    cond = vim.g.vscode == nil,
    config = function()
      require("tint").setup {
        tint = -45,  -- Darken colors, use a positive value to brighten
        saturation = 0.6,  -- Saturation to preserve
      }
    end
  },

  -- vim plugins
  {
    'direnv/direnv.vim',
    lazy = true,
    init = function()
      vim.g.direnv_silent_load = 1
    end
  },
  {
    "andymass/vim-matchup",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "" }
      vim.g.matchup_matchparen_deferred = 1
      vim.g.matchup_matchparen_hi_surround_always = 1
    end,
    config = function()
      require'nvim-treesitter.configs'.setup {
        matchup = {
          enable = true,              -- mandatory, false will disable the whole extension
          disable_virtual_text = true,
          -- [options]
        }
      }
    end
  },
  {
    -- auto adjust indent length and format (tab or space)
    "tpope/vim-sleuth",
    lazy = false
  },

  -- {
  --   'neoclide/coc.nvim',
  --   lazy = true,
  --   build = 'yarn install --frozen-lockfile',
  --   init = function()
  --     vim.g.coc_config_home=vim.fn.glob(vim.fn.stdpath('data'))
  --   end,
  --   config = function()
  --     vim.keymap.set('n', '<leader><leader>', '<cmd>CocCommand<cr>', { silent = true })
  --   end
  -- },

  {
    "potamides/pantran.nvim",
    cond = vim.g.vscode == nil,
    keys = {{"<leader>y", mode = {'n', 'x'}}},
    config = function()
      local opts = {noremap = true, silent = true, expr = true}
      local pantran = require("pantran")
      vim.keymap.set("n", "<leader>y", pantran.motion_translate, opts)
      vim.keymap.set("n", "<leader>yy", function() return pantran.motion_translate() .. "_" end, opts)
      vim.keymap.set("x", "<leader>y", pantran.motion_translate, opts)

      require("pantran").setup {
        default_engine = "google",
        engines = {
          deepl = {
            default_target = "ZH",
            auth_key = "fb82d24e-df8e-e7f2-5db4-142818d50c12:fx",
          },
          google = {
            fallback = {
              default_target = "zh-CN",
            }
          },
        },
      }
    end
  },
  {
    'luochen1990/rainbow',
    lazy = true,
    config = function()
      -- same as vim rainbow
      vim.g.rainbow_active = 1
      vim.g.rainbow_conf = {
        guifgs = {'#FF0000', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#FF00FF'}, -- table of hex strings
      }
    end
  },
  {
    'iamcco/markdown-preview.nvim',
    lazy = true,
    build = function() vim.fn["mkdp#util#install"]() end,
    cmd = {"MarkdownPreview", "MarkdownPreviewInstall"},
    config = function()
      vim.api.nvim_create_user_command("MarkdownPreview", "echo 'Not a markdown file!'", { nargs = 0 })
      vim.api.nvim_create_user_command("MarkdownPreviewInstall", function () vim.fn["mkdp#util#install"]() end, { nargs = 0 })
      vim.api.nvim_exec_autocmds("BufEnter", {
        group = "mkdp_init",
      })
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_echo_preview_url = 1

      vim.cmd[[
      function! Mkdp_handler(url)
        exec "silent !firefox -new-window " . a:url
      endfunction
      ]]

      vim.g.mkdp_browserfunc = 'Mkdp_handler'
    end
  },
  {
    'kana/vim-textobj-entire',
    keys = {"vie"},
    dependencies = {"kana/vim-textobj-user"},
  },
  {
    'lfv89/vim-interestingwords',
    lazy = true,
    keys = "<leader>h",
    init = function()
      vim.g.interestingWordsDefaultMappings = 0
      vim.g.interestingWordsGUIColors = {'#8CCBEA', '#A4E57E', '#FFDB72', '#FF7272', '#FFB3FF', '#9999FF'}
    end,
    config = function()
      vim.keymap.set('n', '<leader>h', "<cmd>call InterestingWords('n')<cr>", { silent = true })
      vim.keymap.set('v', '<leader>h', "<cmd>call InterestingWords('v')<cr>", { silent = true })
      vim.keymap.set('n', '<leader>H', "<cmd>call UncolorAllWords()<cr>", { silent = true })
    end
  },
  {'honza/vim-snippets', lazy = true },
  {
    'L3MON4D3/LuaSnip',
    lazy = true,
    dependencies = {
      {'honza/vim-snippets', rtp = '.'},
    },
    config = function()
      vim.opt.rtp:prepend(os.getenv("HOME") .. '/dotfiles/.vim')
      require("luasnip.loaders.from_snipmate").lazy_load()
      require("dotfiles.luasnip")
      local ls = require("luasnip")
      ls.setup({
          update_events = {"TextChanged", "TextChangedI"},
          enable_autosnippets = true
      })

      local t = function(str)
        return vim.api.nvim_replace_termcodes(str, true, true, true)
      end

      vim.keymap.set({"i"}, "<Tab>", function()
        if ls.expand_or_jumpable() then
          return ls.expand_or_jump()
        else
          vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
        end
      end, {silent = true})
      vim.keymap.set({"i", "s"}, "<Tab>", function()
        if ls.jumpable(1) then
          return ls.jump(1)
        else
          vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
        end
      end, {silent = true})
      vim.keymap.set({"i", "s"}, "<S-Tab>", function()
        if ls.jumpable(-1) then
          return ls.jump(-1)
        else
          vim.api.nvim_feedkeys(t("<S-Tab>"), "n", true)
        end
      end, {silent = true})

      local function snips_edit()
        local ft = vim.bo.filetype
        vim.cmd("e ~/dotfiles/.vim/snippets/" .. ft .. ".snippets")
      end
      vim.keymap.set('n', '<leader>ss', snips_edit, { silent = true })
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "*.snippets",
        callback = function()
          vim.bo.filetype = "snippets"
        end
      })

      -- map <BS> to <BS>i to get in insert
      vim.keymap.set({"s"}, "<BS>", "<BS>i", {silent = true, noremap = true})
    end
  },

  {
    'github/copilot.vim',
    lazy = true,
    init = function()
      vim.g.copilot_filetypes = {
        ["dap-repl"] = false,
        dapui_watches = false,
        markdown = true
      }
    end,
    config = function()
      vim.g.copilot_echo_num_completions = 1
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_tab_fallback = ""

      function copilot_dismiss()
        local copilot_keys = vim.fn["copilot#Dismiss"]()
        local t = function(str)
          return vim.api.nvim_replace_termcodes(str, true, true, true)
        end

        if copilot_keys ~= "" then
          vim.api.nvim_feedkeys(copilot_keys, "i", true)
        else
          vim.api.nvim_feedkeys(t("<End>"), "i", true)
        end
      end
      vim.keymap.set('i', '<C-e>', "<Cmd>lua copilot_dismiss()<CR>", { silent = true})
      vim.keymap.set('i', '<M-\\>', "<Cmd>Copilot panel<CR>", { silent = true})
    end
  },

  {
    "jellydn/CopilotChat.nvim",
    dependencies = { "github/copilot.vim" },
    build = ":UpdateRemotePlugins",
    opts = {
      show_help = "yes", -- Show help text for CopilotChatInPlace, default: yes
      debug = false, -- Enable or disable debug mode, the log file will be in ~/.local/state/nvim/CopilotChat.nvim.log
    },
    cmd = {
      "CopilotChatExplain",
      "CopilotChatTests",
      "CopilotChatVisual",
      "CopilotChatInPlace",
    },
  },

  {
    "lambdalisue/suda.vim",
    cmd = {"SudaRead", "SudaWrite"}
  },
  {
    'mbbill/undotree',
    keys = "U",
    config = function()
      vim.keymap.set('n', 'U', '<cmd>UndotreeToggle<cr>', { silent = true })
    end
  },
  {
    'machakann/vim-sandwich',
    lazy = true,
    init = function()
      vim.g.sandwich_no_default_key_mappings = 1
    end,
    config = function()
      vim.cmd[[
      runtime macros/sandwich/keymap/surround.vim

      xmap is <Plug>(textobj-sandwich-query-i)
      xmap as <Plug>(textobj-sandwich-query-a)
      omap is <Plug>(textobj-sandwich-query-i)
      omap as <Plug>(textobj-sandwich-query-a)

      xmap iss <Plug>(textobj-sandwich-auto-i)
      xmap ass <Plug>(textobj-sandwich-auto-a)
      omap iss <Plug>(textobj-sandwich-auto-i)
      omap ass <Plug>(textobj-sandwich-auto-a)
      ]]
    end
  },

  {'MTDL9/vim-log-highlighting', lazy = true},

  {
    'GustavoKatel/telescope-asynctasks.nvim',
    lazy = true,
    keys = {"<leader>at", "<leader>ae"},
    cmd = "AsyncTaskTelescope",
    config = function()
      require('lazy').load{plugins = {'asynctasks.vim', 'asyncrun.vim'}}
      -- Fuzzy find over current tasks
      vim.cmd[[command! AsyncTaskTelescope lua require("telescope").extensions.asynctasks.all()]]
      vim.keymap.set('n', '<leader>at', '<cmd>AsyncTaskTelescope<cr>', { silent = true })
    end
  },


  {
    'skywind3000/asynctasks.vim',
    lazy = true,
    dependencies = {'skywind3000/asyncrun.vim'},
    config = function()
      vim.g.asyncrun_open = 6
      vim.g.asynctasks_term_pos = 'bottom'
      vim.g.asynctasks_term_rows = 14
      vim.keymap.set('n', '<leader>ae', '<cmd>AsyncTaskEdit<cr>', { silent = true })
    end
  },

  {'skywind3000/asyncrun.vim', lazy = true},

  {
    'KabbAmine/vCoolor.vim',
    lazy = true,
    keys = "<leader>cp",
    init = function()
      vim.g.vcoolor_disable_mappings = 1
    end,
    config = function()
      vim.g.vcoolor_disable_mappings = 1
      vim.keymap.set('n', '<leader>cp', '<cmd>VCoolor<cr>', { silent = true })
    end
  },

  {
    'tpope/vim-fugitive',
    lazy = true,
    cmd = {"G", "Gclog", "Gvdiffsplit"}
  },

  {
    'rbong/vim-flog',
    lazy = true,
    cmd = {"Flog"},
    dependencies = {'tpope/vim-fugitive'}
  },

  {
    'mg979/vim-visual-multi',
    lazy = true,
    init = function()
      vim.g.VM_leader = '\\'
    end,
    keys = {{"<C-n>", mode = {'n', 'v', 'x'}}},
    config = function()
      vim.g.VM_theme = 'neon'
    end
  },

  {
    "dhananjaylatkar/cscope_maps.nvim",
    lazy = true,
    dependencies = {"folke/which-key.nvim"},
    config = function()
      require('cscope_maps').setup({
        disable_maps = false, -- true disables my keymaps, only :Cscope will be loaded
        skip_input_prompt = true,
        cscope = {
          -- location of cscope db fils
          db_file = './cscope.out',
          -- cscope executable
          exec = "cscope", -- "cscope" or "gtags-cscope"
          -- choose your fav picker
          picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
          -- "true" does not open picker for single result, just JUMP
          skip_picker_for_single_result = true, -- "false" or "true"
          -- these args are directly passed to "cscope -f <db_file> <args>"
          db_build_cmd_args = { "-bqkv" },
          -- statusline indicator, default is cscope executable
          statusline_indicator = nil,
        },
      })
    end
  },
  {
    --管理gtags，集中存放tags
    'skywind3000/vim-gutentags',
    lazy = true,
    init = function()
      vim.g.gutentags_define_advanced_commands = 1
    end,
    config = function()
      -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
      vim.g.gutentags_modules = {'ctags', 'gtags_cscope', 'cscope_maps'}

      -- config project root markers.
      vim.g.gutentags_project_root = {'.root', '.svn', '.git', '.hg', '.project', '.exrc', "pom.xml"}

      -- generate datebases in my cache directory, prevent gtags files polluting my project
      vim.g.gutentags_cache_dir = os.getenv("HOME") .. '/.cache/tags'

      -- change focus to quickfix window after search (optional).
      vim.g.gutentags_plus_switch = 1

      vim.g.gutentags_load = 1

    end
  },

  {
    'skywind3000/gutentags_plus',
    init = function()
      vim.g.gutentags_plus_nomap = 1
    end,
    lazy = true,
    config = function()
      vim.cmd [[
        noremap <silent> <leader>cgs :GscopeFind s <C-R><C-W><cr>
        noremap <silent> <leader>cgg :GscopeFind g <C-R><C-W><cr>
        noremap <silent> <leader>cgc :GscopeFind c <C-R><C-W><cr>
        noremap <silent> <leader>cgt :GscopeFind t <C-R><C-W><cr>
        noremap <silent> <leader>cge :GscopeFind e <C-R><C-W><cr>
        noremap <silent> <leader>cgf :GscopeFind f <C-R>=expand("<cfile>")<cr><cr>
        noremap <silent> <leader>cgi :GscopeFind i <C-R>=expand("<cfile>")<cr><cr>
        noremap <silent> <leader>cgd :GscopeFind d <C-R><C-W><cr>
        noremap <silent> <leader>cga :GscopeFind a <C-R><C-W><cr>
        noremap <silent> <leader>cgz :GscopeFind z <C-R><C-W><cr>
      ]]
    end,
  },

  -- dap
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "mfussenegger/nvim-dap-python",
      "rcarriga/cmp-dap",
      'Weissle/persistent-breakpoints.nvim',
    },
    keys = {
      "<F5>",
      "<F9>",
    },
    init = function()
      vim.cmd('hi debugRed guifg=red')
      vim.fn.sign_define('DapBreakpoint', {text='🛑', texthl='debugRed', linehl='', numhl=''})
    end,
    config = function()
      local function term_dap()
        require("dapui").close()
        require 'nvim-dap-virtual-text/virtual_text'.clear_virtual_text()
      end

      local dap = require('dap')
      local persist_bp = require('persistent-breakpoints.api')
      dap.defaults.fallback.terminal_win_cmd = 'vertical rightbelow 50new'
      vim.keymap.set('n', '<F2>', function() dap.terminate({},{terminateDebuggee=true}, term_dap()) end, { silent = true })
      vim.keymap.set('n', '<F5>', dap.continue, { silent = true })
      vim.keymap.set('n', '<leader><F5>', dap.run_to_cursor, { silent = true })
      vim.keymap.set('n', '<F6>', dap.pause, { silent = true })
      vim.keymap.set('n', '<F6>', dap.pause, { silent = true })
      vim.keymap.set('n', '<F10>', dap.step_over, { silent = true })
      vim.keymap.set('n', '<F11>', dap.step_into, { silent = true })
      vim.keymap.set('n', '<F12>', dap.step_out, { silent = true })
      vim.keymap.set('n', '<F9>', persist_bp.toggle_breakpoint,  { silent = true })
      vim.keymap.set('n', '<leader><F9>', persist_bp.clear_all_breakpoints, { silent = true })
      vim.keymap.set('n', '<F7>', require("dapui").eval, { silent = true })
      vim.keymap.set('v', '<F7>', require("dapui").eval, { silent = true })

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
        id = 'cppdbg',
        type = 'executable',
        command = 'OpenDebugAD7',
      }


      --[[ dap.adapters.codelldb = function(callback, config)
      -- specify in your configuration host = your_host , port = your_port
      callback({ type = "server", host = config.host, port = config.port })
      end ]]

      dap.adapters.lldb = {
        type = 'server',
        port = "${port}",
        executable = {
          -- CHANGE THIS to your path!
          command = 'codelldb',
          args = {"--port", "${port}"},

          -- On windows you may have to uncomment this:
          -- detached = false,
        }
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
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          externalConsole = false,
          -- program = "./${fileBasenameNoExtension}",
          cwd = '${workspaceFolder}',
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description =  'enable pretty printing',
              ignoreFailures = false
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
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          externalConsole = false,
          -- program = "./${fileBasenameNoExtension}",
          cwd = '${workspaceFolder}',
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description =  'enable pretty printing',
              ignoreFailures = false
            },
            {
                description =  "Set Disassembly Flavor to Intel",
                text = "-gdb-set disassembly-flavor intel",
                ignoreFailures = true
            }
          },
        },
        {
          name = "Attach file",
          type = "cppdbg",
          -- type = "lldb",
          request = "attach",
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          -- program = "./${fileBasenameNoExtension}",
          MIMode = 'gdb',
          processId = function()
            return vim.fn.input('procsesID: ')
          end,
          cwd = '${workspaceFolder}',
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description =  'enable pretty printing',
              ignoreFailures = false
            },
          },
        }
      }
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.rust = dap.configurations.cpp
      dap.configurations.asm = dap.configurations.cpp
      vim.api.nvim_create_user_command("DapGDBMemory", function(opts)
        local fargs = opts.fargs
        local tmpfile = vim.fn.tempname()
        print(tmpfile)
        local address = fargs[1] or vim.fn.input('Address: ')
        local size = fargs[2] or 1000
        local cmd = string.format("-exec dump binary memory %s %s %s", tmpfile, address, address .. "+" .. size)
        dap.repl.execute(cmd)
        vim.defer_fn(function()
          vim.cmd("e " .. tmpfile)
          vim.cmd("%!xxd")
        end, 0)
      end, { nargs = '*' })
      vim.api.nvim_create_user_command("DapListBreakpoints", dap.list_breakpoints, { nargs = 0 })

      -- jump between breakpoints
      local function jump_breakpoints(up)
        local bufnr = vim.api.nvim_get_current_buf()
        local bps = require("dap.breakpoints").get()[bufnr]
        if bps == nil or #bps == 0 then
          vim.api.nvim_echo({{"No breakpoints", "WarningMsg"}}, false, {})
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
          vim.api.nvim_win_set_cursor(0, {nearest.line, 0})
          return
        end
        if up then
          vim.api.nvim_win_set_cursor(0, {bps[#bps].line, 0})
        else
          vim.api.nvim_win_set_cursor(0, {bps[1].line, 0})
        end
      end
      vim.keymap.set('n', ']b', function() jump_breakpoints(false) end, { silent = true })
      vim.keymap.set('n', '[b', function() jump_breakpoints(true) end, { silent = true })

      -- Java use nvim-jdtls
      -- Python use nvim-dap-python

      -- Go
      dap.adapters.go = {
        type = 'server',
        port = '${port}',
        executable = {
          command = 'dlv',
          args = {'dap', '-l', '127.0.0.1:${port}'},
        }
      }

      -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
      dap.configurations.go = {
        {
          type = "go",
          name = "Debug",
          request = "launch",
          program = "${file}"
        },
        {
          type = "go",
          name = "Debug test", -- configuration for debugging test files
          request = "launch",
          mode = "test",
          program = "${file}"
        },
        -- works with go.mod packages and sub packages
        {
          type = "go",
          name = "Debug test (go.mod)",
          request = "launch",
          mode = "test",
          program = "./${relativeFileDirname}"
        }
      }

      -- Dap load launch.json from vscode when avaliable
      vim.api.nvim_create_autocmd("DirChanged", {
        pattern = "*",
        callback = function()
          if vim.fn.filereadable("./.vscode/launch.json") then
            require('dap.ext.vscode').load_launchjs(nil, { cppdbg = { 'c', 'cpp', 'asm' }, lldb = { 'rust' } })
          end
        end
      })
      if vim.fn.filereadable("./.vscode/launch.json") then
        require('dap.ext.vscode').load_launchjs(nil, { cppdbg = { 'c', 'cpp', 'asm' }, lldb = { 'rust' } })
      end
    end
  },
  {
    'mfussenegger/nvim-dap-python',
    config = function()
      require('dap-python').setup()
    end
  },
  {
    "rcarriga/nvim-dap-ui",
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
      vim.cmd [[
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
      ]]

    end
  },
  {
    'theHamsta/nvim-dap-virtual-text',
    config = function()
      require("nvim-dap-virtual-text").setup {
        enabled = true,                     -- enable this plugin (the default)
        enabled_commands = true,            -- create commands DapVirtualTextEnable, DapVirtualTextDisable, DapVirtualTextToggle, (DapVirtualTextForceRefresh for refreshing when debug adapter did not notify its termination)
        highlight_changed_variables = true, -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
        highlight_new_as_changed = false,   -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
        show_stop_reason = true,            -- show stop reason when stopped for exceptions
        commented = false,                  -- prefix virtual text with comment string
        -- experimental features:
        virt_text_pos = 'eol',              -- position of virtual text, see `:h nvim_buf_set_extmark()`
        all_frames = false,                 -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
        virt_lines = false,                 -- show virtual lines instead of virtual text (will flicker!)
        virt_text_win_col = nil             -- position the virtual text at a fixed window column (starting from the first text column) ,
        -- e.g. 80 to position at column 80, see `:h nvim_buf_set_extmark()`
      }
    end
  },
  {
    'Weissle/persistent-breakpoints.nvim',
    config = function()
      require('persistent-breakpoints').setup{
        load_breakpoints_event = { "BufReadPost" }
      }
      -- load for once on plugin loaded
      require("persistent-breakpoints.api").load_breakpoints()
    end
  },
}

local pattern
if use_nix then pattern = "." else pattern = "*" end
local lazy_opts =  {
  defaults = {
    lazy = true
  },
  dev = {
    path = vim.fn.stdpath("data") .. "/nix",
    patterns = {pattern},
    fallback = true,
  },
  install = {
    missing = false
  }
}

require('lazy').setup(plugins, lazy_opts)


-- `nvim --headless --cmd "let g:plugins_loaded=1" -c 'lua DumpPluginsList(); vim.cmd("q")'`
function DumpPluginsList()
  for _, plugin in ipairs(plugins) do
    opt = {}
    if plugin.branch ~= nil then
      opt.branch = plugin.branch
    end
    if plugin.build ~= nil then
      opt.build = true
    end
    if plugin.dependencies ~= nil then
      opt.dependencies = plugin.dependencies
    end
    if plugin.commit ~= nil then
      opt.commit = plugin.commit
    end
    if plugin[1] ~= nil then
      print(plugin[1], vim.json.encode(opt))
    else
      print(plugin.url, vim.json.encode(opt))
    end
    print("\n")
  end
  print('\n')
end

----------------------------Highlights------------------------------------------------
local links = {
  -- semantic highlighting
  ['@lsp.type.class'] = 'Class',
  ['@lsp.type.comment'] = 'Comment',
  ['@lsp.type.namespace'] = 'Class',
  ['@lsp.type.enum'] = 'Enum',
  ['@lsp.type.interface'] = 'Class',
  ['@lsp.type.typeParameter'] = 'TypeParameter',
  ['@lsp.type.enumMember'] = 'Constant',
  ['@lsp.type.regexp'] = 'SpecialChar',
  ['@lsp.type.decorator'] = 'PreProc',
  ['@lsp.type.struct'] = 'Class',
  ['@lsp.type.property'] = 'Property',
  ['@lsp.type.selfKeyword'] = 'Parameter',
  ['@lsp.type.parameter'] = 'Parameter',
  ['@lsp.typemod.variable.readonly'] = 'Constant',
  ['@lsp.mod.static'] = 'Constant',

  -- language specific
  ['@lsp.type.type.go'] = 'Class',
  ['@lsp.type.defaultLibrary.go'] = 'Type',
  ['@lsp.type.defaultLibrary.go'] = 'Type',
  ['@lsp.type.path.nix'] = 'String',
  ['@lsp.mod.definition.nix'] = 'Normal',
  ['@lsp.type.module.python'] = 'Class',

  -- treesitter
  ['@type'] = 'Class',
  ['@type.qualifier'] = 'Keyword',
  ['@type.builtin'] = 'Type',
  ['@function.macro.latex'] = 'Keyword',
  ['@namespace.latex'] = 'PreProc',
  ['@text.reference.latex'] = 'Class',
  ['@punctuation.special.latex'] = 'Keyword',
}
for newgroup, oldgroup in pairs(links) do
  vim.api.nvim_set_hl(0, newgroup, { link = oldgroup, default = true })
end

--------------------------------------------------------------------------------------
----------------------------Lazy Load-------------------------------------------------
local function load_by_filetype(ft_plugins)
  for _, ft_plugin in pairs(ft_plugins) do
    for _, ft in pairs(ft_plugin.ft) do
      if vim.bo.filetype == ft then
        require('lazy').load { plugins = ft_plugin.plugins }
        goto continue
      end
    end

    vim.api.nvim_create_augroup("LazyLoadFiletype", {})
    vim.api.nvim_create_autocmd("FileType", {
      pattern = ft_plugin.ft,
      group = "LazyLoadFiletype",
      callback = function(ev, opts)
        require('lazy').load { plugins = ft_plugin.plugins }

        -- load ftplugin, defer to avoid recursive call
        vim.defer_fn(function()
          vim.api.nvim_exec_autocmds("FileType", {
            pattern = ft_plugin.ft,
          })
        end, 0)
      end,
      once = true
    })
    ::continue::
  end
end
function LazyLoadPlugins()
  load_by_filetype {
    {
      ft = { "java" },
      plugins = { 'nvim-jdtls' }
    },
    {
      ft = { "c", "cpp" },
      plugins = { 'clangd_extensions.nvim' }
    },
    {
      ft = { "rust" },
      plugins = { 'rustaceanvim' }
    }
  }

  require('lazy').load {
    plugins = {
      -- begin lsp
      'clangd_extensions.nvim',
      'nvim-lightbulb',
      'fidget.nvim',
      'none-ls.nvim',
      'lsp_signature.nvim',
      'dropbar.nvim',
      -- end lsp

      -- begin git
      'gitsigns.nvim',
      'git-conflict.nvim',
      -- end git

      -- begin vim plugins
      'vim-sandwich',
      'vim-log-highlighting',
      'vim-visual-multi',
      -- 'coc.nvim',
      -- end vim plugins

      -- begin ui
      'dressing.nvim',
      'nvim-colorizer.lua',
      'bufferline.nvim',
      'nvim-notify',
      'nvim-hlslens',
      'satellite.nvim',
      'lualine.nvim',
      'alpha-nvim',
      'todo-comments.nvim',
      'statuscol.nvim',
      -- end ui

      -- begin misc
      'which-key.nvim',
      'project.nvim',
      'nvim-ufo',
      'toggleterm.nvim',
      'copilot.vim',
      'direnv.vim',
      'nvim-dap',
      -- end misc

      -- begin cmp
      'nvim-cmp',
      -- end cmp
    }
  }

  -- replace netrw
  local function open_nvim_tree(data)

    -- buffer is a directory
    local directory = vim.fn.isdirectory(data.file) == 1

    if not directory then
      return
    end

    -- change to the directory
    vim.cmd.cd(data.file)

    -- open the tree
    vim.defer_fn(require("nvim-tree.api").tree.open, 0)
  end
  vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

  vim.api.nvim_create_autocmd("InsertEnter", {
    callback = function()
      require('lazy').load{
        plugins = {
          -- begin cmp
          'cmp-nvim-lsp',
          'cmp-nvim-lua',
          'cmp-path',
          'cmp-buffer',
          'cmp-omni',
          'cmp-nvim-lsp-signature-help',
          'cmp-dictionary',
          -- end cmp
        }
      }
    end,
    once = true
  })

  if vim.b.treesitter_disable ~= 1 then
    require('lazy').load{
      plugins = {
        -- begin treesitter (slow performance)
        'rainbow-delimiters.nvim',   -- performance issue
        'indent-blankline.nvim',
        'nvim-treesitter-context',
        'nvim-ts-autotag',
        'hlargs.nvim',
        'vim-matchup',
        'vim-illuminate',
        'nvim-treesitter-textobjects'
        -- end treesitter
      }
    }
  else
    vim.treesitter.stop()
    require('lazy').load {
      plugins = {
        'rainbow',
      }
    }
    vim.schedule(function()
      vim.fn["rainbow_main#load"]()
    end)
  end

  -- change <leader><leader> to telescope commands
  vim.keymap.set('n', '<leader><leader>', '<cmd>Telescope cmdline<cr>', { silent = true })
end

function loadTags()
  require('lazy').load { plugins = { 'cscope_maps.nvim', 'vim-gutentags', 'gutentags_plus' } }
  vim.cmd("edit %")
  vim.keymap.set('n', '<leader>gt', "<cmd>exec 'ltag ' . expand('<cword>') . '| lopen' <CR>", { silent = false })
end
vim.cmd("command! LoadTags lua loadTags()")

--------------------------------------------------------------------------------------
----------------------------Constant Plugins------------------------------------------
-- quick fix
function _G.qftf(info)
  require('lazy').load { plugins = { 'nvim-bqf' } }
  local items
  local ret = {}
  if info.quickfix == 1 then
    items = vim.fn.getqflist({id = info.id, items = 0}).items
  else
    items = vim.fn.getloclist(info.winid, {id = info.id, items = 0}).items
  end
  local limit = 99
  -- get maximum length of file name
  local max = 0
  for i = info.start_idx, info.end_idx do
    local e = items[i]
    if e.valid == 1 then
      if e.bufnr > 0 then
        local fname = vim.fn.bufname(e.bufnr)
        if max < #fname then
          max = #fname
        end
      end
    end
  end
  local length = 0
  if max < limit then
    length = max
  else
    length = limit
  end
  local fname_fmt1, fname_fmt2 = '%-' .. length .. 's', '…%.' .. (length - 1) .. 's'
  local valid_fmt = '%s │%5d:%-3d│%s %s'
  for i = info.start_idx, info.end_idx do
    local e = items[i]
    local fname = ''
    local str
    if e.valid == 1 then
      if e.bufnr > 0 then
        fname = vim.fn.bufname(e.bufnr)
        if fname == '' then
          fname = '[no name]'
        else
          fname = fname:gsub('^' .. os.getenv("HOME"), '~')
        end
        -- char in fname may occur more than 1 width, ignore this issue in order to keep performance
        if #fname <= length then
          fname = fname_fmt1:format(fname)
        else
          fname = fname_fmt2:format(fname:sub(1 - length))
        end
      end
      local lnum = e.lnum > 99999 and -1 or e.lnum
      local col = e.col > 999 and -1 or e.col
      local qtype = e.type == '' and '' or ' ' .. e.type:sub(1, 1):upper()
      str = valid_fmt:format(fname, lnum, col, qtype, e.text)
    else
      str = e.text
    end
    table.insert(ret, str)
  end
  return ret
end

vim.o.qftf = '{info -> v:lua._G.qftf(info)}'

-- vim.g.suda_smart_edit = 1

-- neovide has its own clipboard system
if vim.g.neovide == nil then
  -- osc52 support on ssh
  if os.getenv("SSH_CONNECTION") ~= nil then
    -- disable the xclip under SSH due to high lantency
    -- use osc52
    local nvim_ver_minor = vim.version().minor
    if nvim_ver_minor >= 10 then
      -- TODO: paste from ssh
      vim.g.clipboard = {
        name = 'OSC 52',
        copy = {
          ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
          ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
        },
        paste = {
          ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
          ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
        },
      }
    else
      vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function()
          if have_load_osc52 == nil then
            have_load_osc52 = 1
            require("lazy").load{ plugins = {"nvim-osc52"} }
          end
          if vim.v.event.operator == 'y' and vim.v.event.regname == '' then
            local osc52_copy_register = require('osc52').copy_register
            pcall(osc52_copy_register, '"')
          end
        end
      })
    end
  elseif vim.fn.has('wsl') == 1 then
    -- wsl without ssh connection
    if vim.fn.executable("win32yank.exe") == 1 then
      vim.g.clipboard = {
        name = 'win32yank',
        -- TODO: may change to async here
        copy = {
          ['+'] = {"win32yank.exe", "-i", "--crlf"},
          ['*'] = {"win32yank.exe", "-i", "--crlf"},
        },
        paste = {
          ['+'] = {"win32yank.exe", "-o", "--lf"},
          ['*'] = {"win32yank.exe", "-o", "--lf"},
        },
      }
    end
  end
end

if vim.g.vscode == nil then
  require('fundo').setup()
end

-- vim skeletons
vim.api.nvim_create_autocmd("BufNewFile", {
  callback = function()
    require("dotfiles.skeletons").insert_skeleton {
      username = "qsdrqs",
      email = "qsdrqs@gmail.com"
    }
  end
})

-- begin im switch
local im_switch
local default_im
local restored_im
local is_windows = false
local im_switch_job
local function all_trim(s)
  return s:match("^%s*(.-)%s*$")
end
if vim.fn.has('wsl') == 1 and os.getenv("SSH_CONNECTION") == nil then
  im_switch = "im-select.exe"
  default_im = "1033"
  is_windows = true
else
  im_switch = "fcitx5-remote"
  default_im = "keyboard-us"
end
if vim.fn.executable(im_switch) ~= 0 then
  if is_windows then
    im_switch_job = require'plenary.job':new({
      command = im_switch,
      on_stdout = vim.schedule_wrap(function(_, data)
        restored_im = all_trim(data)
        if restored_im ~= default_im then
          -- TODO: may change to async here
          vim.fn.system(im_switch .. " " .. default_im)
        end
      end),
    })
  end
  vim.api.nvim_create_autocmd({"InsertLeave"}, {
    callback = function()
      if not is_windows then
        restored_im = all_trim(vim.fn.system(im_switch .. " -n"))
        if restored_im ~= default_im then
          vim.fn.system(im_switch .. " -s " .. default_im)
        end
      else
        -- async switch
        im_switch_job:start()
      end
    end
  })
  vim.api.nvim_create_autocmd({"InsertEnter"}, {
    callback = function()
      if not is_windows then
        if restored_im ~= nil and restored_im ~= default_im then
          vim.fn.system(im_switch .. " -s " .. restored_im)
        end
      else
        if restored_im ~= nil and restored_im ~= default_im then
          vim.fn.system(im_switch .. " " .. restored_im)
        end
      end
    end
  })
end
-- end im switch

-- workaround for https://github.com/neovim/neovim/issues/21856
vim.api.nvim_create_autocmd({ "VimLeave" }, {
  callback = function()
    vim.cmd('sleep 10m')
  end,
})

-- improve performance
vim.keymap.set('n', '<leader>pf', "<cmd>IBLToggleScope<cr><cmd>TSToggle highlight<cr>", { silent = true })

---------------------------vscode neovim----------------------------------------------
function VscodeNeovimHandler()
  local vscode = require("vscode-neovim")

  require('lazy').load{
    plugins = {
      "vim-visual-multi",
      "nvim-treesitter-textobjects",
      "vim-matchup",
      "vim-sandwich",
      "gitsigns.nvim",
    }
  }

  vim.keymap.set('n', '<leader>af',function() vscode.action("editor.action.formatDocument") end, { silent = true })
  vim.keymap.set('v', '<leader>af',function() vscode.action("editor.action.formatSelection") end, { silent = true })
  vim.keymap.set('n', 'gi',function() vscode.action("editor.action.goToImplementation") end, { silent = true })
  vim.keymap.set('n', 'gr',function() vscode.action("editor.action.goToReferences") end, { silent = true })
  vim.keymap.set('n', 'gD',function() vscode.action("editor.action.goToDeclaration") end, { silent = true })
  vim.keymap.set('n', '<leader>v',function() vscode.action("workbench.action.toggleAuxiliaryBar") end, { silent = true })
  vim.keymap.set('n', '<leader>n',function() vscode.action("workbench.action.toggleSidebarVisibility") end, { silent = true })
  vim.keymap.set('n', '<leader>rs',function() vscode.action("workbench.action.reloadWindow") end, { silent = true })
  vim.keymap.set('n', '<leader>q',function() vscode.action("workbench.actions.view.toggleProblems") end, { silent = true })
  vim.keymap.set('n', ']d',function() vscode.action("editor.action.marker.next") end, { silent = true })
  vim.keymap.set('n', '[d',function() vscode.action("editor.action.marker.prev") end, { silent = true })
  vim.keymap.set('n', '<leader>x',function() vscode.action("workbench.action.closeActiveEditor") end, { silent = true })
  vim.keymap.set('n', '<leader>at',function() vscode.action("workbench.action.tasks.runTask") end, { silent = true })
  vim.keymap.set('n', '<leader>ca',function() vscode.action("editor.action.quickFix") end, { silent = true })
  vim.keymap.set('n', '<leader>rn',function() vscode.action("editor.action.rename") end, { silent = true })
  vim.keymap.set('n', '<leader>gg',function() vscode.action("workbench.action.findInFiles") end, { silent = true })
  vim.keymap.set('n', '<leader><leader>',function() vscode.call("workbench.action.showCommands") end, { silent = true })
  vim.keymap.set('n', '<localleader>t',function() vscode.call("workbench.action.createTerminalEditorSide") end, { silent = true })
  vim.keymap.set('n', '<localleader>T',function() vscode.call("workbench.action.createTerminalEditor") end, { silent = true })

  vim.keymap.set('n', 'gh',function() vscode.call("clangd.switchheadersource") end, { silent = true })

  vim.keymap.set('x', '<leader>y',function() vscode.call("extension.translateTextPreferred") end, { silent = true })
  vim.keymap.set('n', '<leader>y',function()
    vim.cmd [[normal! viw]]
    vscode.call("extension.translateTextPreferred")
  end, { silent = true })

  vim.keymap.set('n', '<leader>gs',function()
    vim.cmd [[normal! yiw]]
    vscode.action("workbench.action.findInFiles")
  end, { silent = true })

  vim.keymap.set({'n', 'x'}, '<C-w>o',function()
    vscode.action('workbench.action.joinAllGroups')
    vscode.action("workbench.action.closeAuxiliaryBar")
    vscode.action("workbench.action.closeSidebar")
    vscode.action("workbench.action.closePanel")
  end, { silent = true })

  vim.keymap.set({'n', 'x'}, '<C-w>c',function()
    vscode.action('workbench.action.closeEditorsInGroup')
  end, { silent = true })

  vim.keymap.set('n', '<leader>ya',function()
    vscode.call('multiCommand.createShTerminal')
    vscode.call('workbench.action.terminal.moveToEditor')
    vim.defer_fn(function()
      vscode.call('multiCommand.openFileManager')
      vscode.call('workbench.action.moveEditorToNewWindow')
    end, 200)
  end, { silent = true })

  -- git (use gitsigns.nvim instead)
  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
      local bufnr = args.buf
      -- looks like "/home/qsdrqs/foo/bar"
      local cwd = vim.fn.getcwd()

      -- looks like "__vscode_neovim__-file:///home/qsdrqs/foo/bar/baz.txt" for local file
      -- or "__vscode_neovim__-vscode-remote://wsl%2Barch/home/qsdrqs/foo/bar/baz.txt" for wsl file
      local file_long_name = vim.fn.expand("%")
      -- get relative path
      local relative_name = string.sub(file_long_name, string.len("__vscode_neovim__-file://") + 1)
      local wsl_head = "__vscode_neovim__-vscode-remote://wsl"

      if string.find(relative_name, cwd, 1, true) ~= nil then
        -- local file
        relative_name = string.sub(relative_name, string.len(cwd) + 2)
        require'gitsigns'.attach(bufnr, {
          file = relative_name,
          toplevel = cwd,
          gitdir = cwd .. "/.git",
        })
      elseif string.find(file_long_name, wsl_head, 1, true) ~= nil then
        -- wsl file
        local absolute_path = string.sub(file_long_name, string.len(wsl_head) + string.len("%2Barch") + 1)
        local absolute_path_dir = vim.fn.fnamemodify(absolute_path, ":h")
        local cwd = vim.fn.system("git -C " .. absolute_path_dir .. " rev-parse --show-toplevel")
        cwd = string.sub(cwd, 1, string.len(cwd) - 1)
        local relative_path = string.sub(absolute_path, string.len(cwd) + 2)
        require'gitsigns'.attach(bufnr, {
          file = relative_path,
          toplevel = cwd,
          gitdir = cwd .. "/.git",
        })
      else
        -- remote file, fallback to vscode keybindings
        vim.keymap.set('n', '<leader>gr',function() vscode.action("git.revertSelectedRanges") end, { silent = true })
        vim.keymap.set('n', ']g',function() vscode.action("workbench.action.editor.nextChange") end, { silent = true })
        vim.keymap.set('n', '[g',function() vscode.action("workbench.action.editor.previousChange") end, { silent = true })
      end
    end
  })

  -- just be used for vscode selection
  vim.keymap.set('v', '<leader>v',function() vscode.action("editor.action.goToImplementation") end, { silent = true })

  -- same bindings
  vim.keymap.set('n', '<leader>d',function() vscode.action("editor.action.showHover") end, { silent = true })
  vim.keymap.set('n', '<leader>e',function() vscode.action("errorLens.toggleInlineMessage") end, { silent = true })

  vim.keymap.set('n', '<leader>f',function() vscode.action("workbench.action.quickOpen") end, { silent = true })
  vim.keymap.set('n', '<leader>b',function() vscode.action("workbench.action.quickOpen") end, { silent = true })
  vim.keymap.set('n', '<leader>rf',function() vscode.action("workbench.action.gotoSymbol") end, { silent = true })
  vim.keymap.set('n', '<leader>rw',function() vscode.action("workbench.action.showAllSymbols") end, { silent = true })

  -- recover =
  vim.keymap.del({'n', 'x'}, '=', { expr = true })
  vim.keymap.del('n', '==', { expr = true })

  -- recover gf
  vim.keymap.del({'n', 'x'}, 'gf', { expr = true })

  -- clear background highlight
  vim.cmd[[ hi Normal guibg=None ]]
  vim.cmd[[ hi Visual guibg=None ]]

  -- fold
  vim.keymap.set('n', 'zc',function() vscode.action("editor.fold") end, { silent = true })
  vim.keymap.set('n', 'zC',function() vscode.action("editor.foldRecursively") end, { silent = true })
  vim.keymap.set('n', 'zo',function() vscode.action("editor.unfold") end, { silent = true })
  vim.keymap.set('n', 'zO',function() vscode.action("editor.unfoldRecursively") end, { silent = true })
  vim.keymap.set('n', 'za',function() vscode.action("editor.toggleFold") end, { silent = true })
  vim.keymap.set('n', 'zM',function() vscode.action("editor.foldAll") end, { silent = true })
  vim.keymap.set('n', 'zR',function() vscode.action("editor.foldAll") end, { silent = true })

  vim.keymap.set('n', '<localleader>v',function() vscode.action("latex-workshop.synctex") end, { silent = true })
  vim.keymap.set('n', '<C-g>',function() vscode.action("workbench.view.scm") end, { silent = true })

  -- comment, use vscode builtin comment
  vim.keymap.set({'n', 'v'}, '<C-/>',function() vscode.action("editor.action.commentLine") end, { silent = true })
  vim.keymap.set({'n', 'v'}, '<C-s-/>',function() vscode.action("editor.action.blockComment") end, { silent = true })
  vim.keymap.set('v', '<C-s-/>',function() vscode.action("editor.action.blockComment") end, { silent = true })

  -- rewrap
  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*.tex",
    callback = function()
      if vim.g.wrap_on_insert_leave == 1 then
        vscode.action("rewrap.rewrapComment")
      end
    end
  })

end
--------------------------------------------------------------------------------------
