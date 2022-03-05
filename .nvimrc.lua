--
--           | \ | | ___  __\ \   / /_ _|  \/  |     | |  | | | | / \
--           |  \| |/ _ \/ _ \ \ / / | || |\/| |     | |  | | | |/ _ \
--           | |\  |  __/ (_) \ V /  | || |  | |  _  | |__| |_| / ___ \
--           |_| \_|\___|\___/ \_/  |___|_|  |_| (_) |_____\___/_/   \_\
--------------------------------------------------------------------------------------

require('impatient')
vim.cmd [[packadd packer.nvim]]
local fn = vim.fn
local plugins_path = fn.stdpath('data')..'/plugins'
local install_path = plugins_path .. '/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

require('packer').startup({function(use)
  -- Packer can manage itself
  use {'wbthomason/packer.nvim', opt = false}
  use {'lewis6991/impatient.nvim', opt = false}
  use {'nvim-lua/plenary.nvim' }
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} },
    config = function()
      local action_set = require "telescope.actions.set"

      local function move_selection_next_5(prompt_bufnr)
        action_set.shift_selection(prompt_bufnr, 5)
      end

      local function move_selection_previous_5(prompt_bufnr)
        action_set.shift_selection(prompt_bufnr, -5)
      end

      local status_ok, trouble = pcall(require, "trouble.providers.telescope")
      if status_ok then
        require('telescope').setup {
          defaults = {
            mappings = {
              i = {
                ["<C-j>"] = "move_selection_next",
                ["<c-t>"] = trouble.open_with_trouble,
                ["<C-k>"] = "move_selection_previous",
              },
              n = {
                ["<c-t>"] = trouble.open_with_trouble,
                ["K"] = move_selection_previous_5,
                ["J"] = move_selection_next_5,
              },
            }
          }
        }
      else
        require('telescope').setup {
          defaults = {
            mappings = {
              i = {
                ["<C-j>"] = "move_selection_next",
                ["<C-k>"] = "move_selection_previous",
              },
              n = {
                ["K"] = move_selection_previous_5,
                ["J"] = move_selection_next_5,
              },
            }
          }
        }

      end

      vim.api.nvim_set_keymap('n', '<leader>f', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>b', '<cmd>Telescope buffers<cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>Telescope grep_string <cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>gg', '<cmd>Telescope live_grep <cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>Telescope builtin include_extensions=true <cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>rc', '<cmd>Telescope command_history <cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader><leader>', '<cmd>Telescope commands<cr>', { noremap = true, silent = true })
    end
  }

  use {
    'kevinhwang91/nvim-bqf',
    opt = false,
  } -- better quick fix

  use {
    'kevinhwang91/nvim-hlslens',
    config = function()
      local kopts = {noremap = true, silent = true}

      vim.api.nvim_set_keymap('n', 'n',
      [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
      kopts)
      vim.api.nvim_set_keymap('n', 'N',
      [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
      kopts)
      vim.api.nvim_set_keymap('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

      vim.api.nvim_set_keymap('x', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('x', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('x', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('x', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

      require'hlslens'.setup {
        calm_down = false,
        nearest_only = true,
        nearest_float_when = 'auto'
      }
    end
  }

  use {
    'williamboman/nvim-lsp-installer',
    config = function()
      local lsp_installer = require("nvim-lsp-installer")

      lsp_installer.settings({
        ui = {
          icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗"
          }
        }
      })
    end
  }

  use {
    'mfussenegger/nvim-jdtls',
    config = function()
      -- java
      jdt_config = {
        -- The command that starts the language server
        -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
        cmd = {

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
          '-jar', vim.fn.stdpath('data') .. "/lsp_servers/jdtls/plugins/org.eclipse.equinox.launcher_1.6.400.v20210924-0641.jar",
          -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
          -- Must point to the                                                     Change this to
          -- eclipse.jdt.ls installation                                           the actual version


          -- 💀
          '-configuration', vim.fn.stdpath('data') .. "/lsp_servers/jdtls/config_linux",
          -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
          -- Must point to the                      Change to one of `linux`, `win` or `mac`
          -- eclipse.jdt.ls installation            Depending on your system.


          -- 💀
          -- See `data directory configuration` section in the README
          '-data', os.getenv("HOME") .. '/.cache/jdtls/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

        },

        -- 💀
        -- This is the default if not provided, you can remove it. Or adjust as needed.
        -- One dedicated LSP server & client will be started per unique root_dir
        root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),

        -- Here you can configure eclipse.jdt.ls specific settings
        -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        -- for a list of options
        settings = {
          java = {
          }
        },

        -- Language server `initializationOptions`
        -- You need to extend the `bundles` with paths to jar files
        -- if you want to use additional eclipse.jdt.ls plugins.
        --
        -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
        --
        -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
        init_options = {
          bundles = {
            vim.fn.glob(vim.fn.stdpath('data') .. "/dapinstall/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.35.0.jar")
          }
        },

        on_attach = function(client, bufnr)
          -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
          -- you make during a debug session immediately.
          -- Remove the option if you do not want that.
          require('jdtls').setup_dap({ hotcodereplace = 'auto' })
          common_on_attach(client,bufnr)
        end,
      }
      vim.cmd[[ autocmd FileType java lua require('jdtls').start_or_attach(jdt_config)]]
    end
  }

  use {
    'windwp/nvim-ts-autotag',
    config = function()
      require'nvim-treesitter.configs'.setup {
        autotag = {
          enable = true,
        }
      }
    end
  }

  use {
    'neovim/nvim-lspconfig',
    config = function()
      -- vim.lsp.set_log_level('trace')

      local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

      local lspconfig = require('lspconfig')

      function common_on_attach(client,bufnr)
        local status_ok, aerial = pcall(require, 'aerial')
        if status_ok then
          aerial.on_attach(client, bufnr)
        end
        local status_ok, illuminate = pcall(require, 'illuminate')
        if status_ok then
          illuminate.on_attach(client, bufnr)
        end
      end

      function showDocument()
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
      -- Enable completion triggered by <c-x><c-o>
      vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      vim.api.nvim_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
      -- vim.api.nvim_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
      vim.api.nvim_set_keymap('n', 'gd', '<cmd>Trouble lsp_definitions<CR>', opts)
      -- vim.api.nvim_set_keymap('n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
      -- vim.api.nvim_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
      vim.api.nvim_set_keymap('n', 'gr', '<cmd>Trouble lsp_references<CR>', opts)
      vim.api.nvim_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>aa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>ar', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>al', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>D', '<cmd>Trouble lsp_type_definitions<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
      vim.api.nvim_set_keymap('n', 'gh', '<cmd>ClangdSwitchSourceHeader <CR>', opts)

      local servers = { 'clangd' , 'pyright', 'texlab', 'sumneko_lua', 'rust_analyzer', 'vimls', 'hls' }
      for _, lsp in ipairs(servers) do
        local common_config = {
          -- on_attach = my_custom_on_attach,
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
          end,
          flags = {
            -- This will be the default in neovim 0.7+
            debounce_text_changes = 150,
          },
          handlers = {
          },
        }

        if lsp == 'pyright' then common_config.cmd = {vim.fn.stdpath('data') .. "/lsp_servers/python/node_modules/.bin/pyright-langserver", "--stdio"}
        elseif lsp == 'clangd' then common_config.cmd = {"clangd", "--header-insertion-decorators=0", "-header-insertion=never"}
        elseif lsp == "rust_analyzer" then common_config.cmd = {vim.fn.stdpath('data') .. "/lsp_servers/rust/rust-analyzer"}
        elseif lsp == 'vimls' then common_config.cmd = {vim.fn.stdpath('data') .. "/lsp_servers/vim/node_modules/.bin/vim-language-server", "--stdio"}
        elseif lsp == 'hls' then
          common_config.on_attach = function(client, bufnr) 
            common_on_attach(client,bufnr)
            vim.cmd [[ autocmd InsertLeave,TextChanged <buffer> lua vim.lsp.codelens.refresh() ]]
            vim.lsp.codelens.refresh()
          end
          common_config.handlers["textDocument/codeLens"] = function(err, result, ctx, _)
            if not result or not next(result) then
              vim.lsp.codelens.on_codelens(err, result, ctx, _)
            else
              for _, item in ipairs(result) do
                if item.command then
                  item.command.title = "     🔑 " .. item.command.title
                end
              end
              vim.lsp.codelens.on_codelens(err, result, ctx, _)
            end
          end
        elseif lsp == "texlab" then
          common_config.cmd = {vim.fn.stdpath('data') .. "/lsp_servers/latex/texlab" }
          common_config.on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>v', '<cmd>TexlabForward<cr>', { noremap=true, silent=true })
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>b', '<cmd>TexlabBuild<cr>', { noremap=true, silent=true })
          end
          common_config.settings = {
            texlab = {
              auxDirectory = "latex.out",
              build = {
                onSave = true, -- Automatically build latex on save
                args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
                -- args = { "-pdfxe", "-interaction=nonstopmode", "-synctex=1", "%f", "-outdir=latex.out" },
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
          common_config.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
            vim.lsp.diagnostic.on_publish_diagnostics, {
              -- Disable virtual_text
              virtual_text = false,
            })
        elseif lsp == "sumneko_lua" then
          local runtime_path = vim.split(package.path, ';')
          table.insert(runtime_path, "lua/?.lua")
          table.insert(runtime_path, "lua/?/init.lua")

          common_config.cmd = {vim.fn.stdpath('data') .. "/lsp_servers/sumneko_lua/extension/server/bin/lua-language-server"}
          common_config.autostart = false
          common_config.settings = {
            Lua = {
              runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
                -- Setup your lua path
                path = runtime_path,
              },
              diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'},
              },
              workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true),
              },
              -- Do not send telemetry data containing a randomized but unique identifier
              telemetry = {
                enable = false,
              },
            },
          }
        end

        lspconfig[lsp].setup(common_config)
      end


      vim.api.nvim_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
      vim.api.nvim_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
      vim.api.nvim_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>q', '<cmd>TroubleToggle document_diagnostics<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>Q', '<cmd>TroubleToggle workspace_diagnostics<CR>', opts)
      vim.api.nvim_set_keymap('n', '<leader>d', '<cmd>lua showDocument()<CR>', opts)



      -- vim.cmd [[au CursorHold <buffer> lua vim.diagnostic.open_float()]]

      -- UI Customization
      local border = {
        {"🭽", "FloatBorder"},
        {"▔", "FloatBorder"},
        {"🭾", "FloatBorder"},
        {"▕", "FloatBorder"},
        {"🭿", "FloatBorder"},
        {"▁", "FloatBorder"},
        {"🭼", "FloatBorder"},
        {"▏", "FloatBorder"},
      }

      -- To instead override globally
      local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
      function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
        opts = opts or {}
        opts.border = opts.border or border
        return orig_util_open_floating_preview(contents, syntax, opts, ...)
      end

      local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- code len
      vim.api.nvim_set_keymap('n', '<leader>cl', '<cmd>lua vim.lsp.codelens.run()<CR>', opts)
      vim.cmd [[hi! link LspCodeLens specialkey]]

    end
  }

  use {
    'kosayoda/nvim-lightbulb',
    config = function()
      vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
    end
  }

  use {
    'j-hui/fidget.nvim',
    config = function()
      require"fidget".setup{}
    end
  }

  use {'kyazdani42/nvim-web-devicons'}
  use {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup{}
      local npairs = require'nvim-autopairs'
      local Rule   = require'nvim-autopairs.rule'

      npairs.add_rules {
        Rule(' ', ' ')
        :with_pair(function (opts)
          local pair = opts.line:sub(opts.col - 1, opts.col)
          if vim.o.filetype == "markdown" then
            return vim.tbl_contains({ '()', '{}' }, pair)
          end
          return vim.tbl_contains({ '()', '[]', '{}' }, pair)
        end),
        Rule('( ', ' )')
        :with_pair(function() return false end)
        :with_move(function(opts)
          return opts.prev_char:match('.%)') ~= nil
        end)
        :use_key(')'),
        Rule('{ ', ' }')
        :with_pair(function() return false end)
        :with_move(function(opts)
          return opts.prev_char:match('.%}') ~= nil
        end)
        :use_key('}'),
        Rule('[ ', ' ]')
        :with_pair(function() return false end)
        :with_move(function(opts)
          return opts.prev_char:match('.%]') ~= nil
        end)
        :use_key(']')
      }
    end
  }

  use {
    "Pocco81/AutoSave.nvim",
    opt = false,
    config = function()
    end
  }

  use {
    'mhartington/formatter.nvim',
    config = function()
      require("formatter").setup({
        filetype = {
          python = {
            function()
              return {
                exe = "python3 -m autopep8",
                args = {
                  "--in-place --aggressive --aggressive",
                  vim.fn.fnameescape(vim.api.nvim_buf_get_name(0))
                },
                stdin = false,
                ignore_exitcode = true,
              }
            end
          }
        }
      })
      vim.api.nvim_set_keymap("n", "<leader>af", "<cmd>lua formatBuf('n')<CR>", {noremap = true, silent = true })
      vim.api.nvim_set_keymap("v", "<leader>af", "<cmd>lua formatBuf('v')<CR>", {noremap = true, silent = true })

      -- formatters
      function formatBuf(vmode)
        local modes = {"i", "s"}
        local mode = vim.fn.mode()

        for _,v in pairs(modes) do
          if mode == v then
            return
          end
        end

        local no_lsp_formatters = {'python'}
        for _,v in pairs(no_lsp_formatters) do
          if vim.o.filetype == v then
            vim.cmd("Format")
            return
          end
        end
        if vmode == 'v' then
          vim.lsp.buf.range_formatting()
        else
          vim.lsp.buf.formatting()
        end
      end

      function formatTriggerHandler()
        if vim.g.format_on_save == 1 then
          vim.defer_fn(formatBuf, 1000)
        end
      end

      function formatTrigger()
        if not vim.g.format_on_save or vim.g.format_on_save == 0 then
          vim.g.format_on_save = 1
          print("Format On Save: ON")
        elseif vim.g.format_on_save == 1 then
          vim.g.format_on_save = 0
          print("Format On Save: OFF")
        end
      end


      -- defer 1000 ms for formatters
      vim.cmd[[ au BufWritePost * silent lua formatTriggerHandler()]]
      -- vim.cmd[[ au BufWritePost <buffer> silent lua vim.defer_fn(formatBuf, 1000) ]]
      vim.cmd[[ command! AFTrigger lua formatTrigger() ]]
    end
  }

  -- complete
  use { 'quangnguyen30192/cmp-nvim-ultisnips',  }
  use { 'hrsh7th/cmp-nvim-lsp',  }
  -- use { 'hrsh7th/cmp-vsnip',  }
  -- use { 'hrsh7th/vim-vsnip',  }
  use { 'hrsh7th/cmp-nvim-lua',  }
  use { 'hrsh7th/cmp-path', }
  use { 'hrsh7th/cmp-buffer',  }
  use { 'hrsh7th/cmp-omni',  }
  use {
    'uga-rosa/cmp-dictionary',
    config = function()
      require("cmp_dictionary").setup({ dic = { ["markdown,tex"] = { "/usr/share/dict/words" } }, })
    end
  }
  use {
    'hrsh7th/cmp-cmdline',
    keys = {"/", ":"},
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
  }

  use {
    'ray-x/lsp_signature.nvim',
    config = function()
      require "lsp_signature".setup({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
        floating_window = true,
        floating_window_above_cur_line = false,
        handler_opts = {
          border = "rounded"
        }
      })
    end
  }

  use {
    'hrsh7th/nvim-cmp',
    config = function()
      local t = function(str)
        return vim.api.nvim_replace_termcodes(str, true, true, true)
      end
      local cmp = require('cmp')

      local kind_icons = {
        Text = "",
        Method = "",
        Function = "",
        Constructor = "",
        Field = "",
        Variable = "",
        Class = "ﴯ",
        Interface = "",
        Module = "",
        Property = "ﰠ",
        Unit = "",
        Value = "",
        Enum = "",
        Keyword = "",
        Snippet = "",
        Color = "",
        File = "",
        Reference = "",
        Folder = "",
        EnumMember = "",
        Constant = "",
        Struct = "",
        Event = "",
        Operator = "",
        TypeParameter = ""
      }

      vim.cmd [[
      " gray
      highlight! CmpItemAbbrDeprecated guibg=NONE gui=strikethrough guifg=#808080
      " blue
      highlight! CmpItemAbbrMatch guibg=NONE guifg=#569CD6 gui=bold
      highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=#569CD6 gui=bold
      " light blue
      highlight! CmpItemKindVariable guibg=NONE guifg=#9CDCFE
      highlight! CmpItemKindInterface guibg=NONE guifg=#9CDCFE
      highlight! CmpItemKindEnum guibg=NONE guifg=#9CDCFE
      " pink
      highlight! CmpItemKindFunction guibg=NONE guifg=#C586C0
      highlight! CmpItemKindMethod guibg=NONE guifg=#C586C0
      " front
      highlight! CmpItemKindText guibg=NONE guifg=#D4D4D4
      highlight! CmpItemKindProperty guibg=NONE guifg=#D4D4D4
      highlight! CmpItemKindUnit guibg=NONE guifg=#D4D4D4
      " yellow
      highlight! CmpItemKindClass guibg=NONE guifg=#FFC33E
      highlight! CmpItemKindKeyword guibg=NONE guifg=#FF5252
      ]]

      cmp.setup{
        formatting = {
          format = function(entry, vim_item)
            -- Kind icons
            vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind) -- This concatonates the icons with the name of the item kind
            -- Source
            --[[ vim_item.menu = ({
              buffer = "[Buffer]",
              nvim_lsp = "[LSP]",
              luasnip = "[LuaSnip]",
              nvim_lua = "[Lua]",
              latex_symbols = "[LaTeX]",
            })[entry.source.name] ]]
            return vim_item
          end
        },

        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
            -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
            vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
          end,
        },
        mapping = {
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
              if cmp.visible() then
                -- cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
                cmp.confirm()
              elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(ultisnips_jump_forward)"), 'm', true)
              else
                local copilot_keys = vim.fn["copilot#Accept"]()
                if copilot_keys ~= "" then
                    vim.api.nvim_feedkeys(copilot_keys, "i", true)
                else
                    vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
                    -- fallback()
                end
              end
            end,
            s = function(fallback)
              if vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(ultisnips_jump_forward)"), 'm', true)
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
              elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
                return vim.api.nvim_feedkeys( t("<Plug>(ultisnips_jump_backward)"), 'm', true)
              else
                fallback()
              end
            end,
            s = function(fallback)
              if vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
                return vim.api.nvim_feedkeys( t("<Plug>(ultisnips_jump_backward)"), 'm', true)
              else
                fallback()
              end
            end
          }),
        },
        sources = cmp.config.sources({
          { name = 'ultisnips' }, -- For ultisnips users.
          { name = 'nvim_lsp' },
          { name = 'omni' },
          { name = 'dictionary', keyword_length = 2 },
          { name = 'path' },
          -- { name = 'vsnip' }, -- For vsnip users.
          { name = 'nvim_lua' },
          { name = 'buffer' },
          -- { name = 'luasnip' }, -- For luasnip users.
          -- { name = 'snippy' }, -- For snippy users.
        }),

        completion = {
          -- autocomplete = false,
          completeopt = 'menu,menuone,noinsert'
        }

      }

      -- vim.api.nvim_set_keymap('i', '<C-x><C-o>', '<Cmd>lua require("cmp").complete()<CR>', { noremap = true, silent = true })
    end
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()

      -- folds by treesitter
      vim.cmd[[ set foldmethod=expr ]]
      vim.o.foldexpr="nvim_treesitter#foldexpr()"

      require 'nvim-treesitter.configs'.setup {
        -- One of "all", "maintained" (parsers with maintainers), or a list of languages
        ensure_installed = {"c", "cpp", "lua", "vim"},

        -- Install languages synchronously (only applied to `ensure_installed`)
        sync_install = false,


        -- List of parsers to ignore installing
        -- ignore_install = { "javascript" },

        highlight = {
          -- `false` will disable the whole extension
          enable = true,

          -- list of language that will be disabled
          disable = {},

          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = true,
        },
      }

      -- disable comment hightlight
      require"nvim-treesitter.highlight".set_custom_captures {
        -- Highlight the @foo.bar capture group with the "Identifier" highlight group.
        ["comment"] = "NONE",
      }

    end

  }

  use {
    'nvim-treesitter/playground',
    config = function()
      require "nvim-treesitter.configs".setup{
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
  }

  use {
    'nvim-treesitter/nvim-treesitter-textobjects',
    config = function()
      require'nvim-treesitter.configs'.setup {
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
    end
  }

  use {
    "lukas-reineke/indent-blankline.nvim",
    -- TODO: start hilight list
    config = function()
      vim.cmd [[
      highlight IndentBlanklineContextStart guisp=#FFFF00 gui=underline

      highlight IndentBlanklineIndent1 guifg=#FF0000 gui=nocombine
      highlight IndentBlanklineIndent2 guifg=#FFFF00 gui=nocombine
      highlight IndentBlanklineIndent3 guifg=#00FF00 gui=nocombine
      highlight IndentBlanklineIndent4 guifg=#00FFFF gui=nocombine
      highlight IndentBlanklineIndent5 guifg=#0000FF gui=nocombine
      highlight IndentBlanklineIndent6 guifg=#FF00FF gui=nocombine
      ]]

      require("indent_blankline").setup {
        use_treesitter = true,
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
        show_first_indent_level = true,
        context_highlight_list = {
          "IndentBlanklineIndent1",
          "IndentBlanklineIndent2",
          "IndentBlanklineIndent3",
          "IndentBlanklineIndent4",
          "IndentBlanklineIndent5",
          "IndentBlanklineIndent6",
        },

        filetype_exclude = {"alpha"},
      }
    end
  }
  use {
    "p00f/nvim-ts-rainbow",
    config = function()
      require("nvim-treesitter.configs").setup {
        rainbow = {
          enable = true,
          disable = { }, -- list of languages you want to disable the plugin for
          extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
          max_file_lines = nil, -- Do not enable for files with more than n lines, int
          colors = {'#FF0000', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#FF00FF'}, -- table of hex strings
          -- termcolors = {} -- table of colour name strings
        }
      }

    end
  }

  -- cd to project root
  use {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup {
        patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc" },
        detection_methods = { "lsp", "pattern" },
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }

      require('telescope').load_extension('projects')

    end
  }

  use {
    'stevearc/aerial.nvim',
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>v', '<cmd>AerialToggle!<CR>', { noremap = true, silent = true })
      backends = { "lsp", "treesitter", "markdown" }
      local status_ok, telescope = pcall(require, "telescope")
      if status_ok then
        telescope.load_extension('aerial')
      end
      require("aerial").setup({
        backends = { "lsp", "treesitter", "markdown" },
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
        max_width = 200,
        disable_max_lines = -1,
      })
    end
  }

-- git signs
  use {
    'lewis6991/gitsigns.nvim',
    requires = {
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
        current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
          delay = 1000,
          ignore_whitespace = false,
        },
        current_line_blame_formatter_opts = {
          relative_time = false
        },
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

          local function map(mode, lhs, rhs, opts)
            opts = vim.tbl_extend('force', {noremap = true, silent = true}, opts or {})
            vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
          end

          -- Navigation
          map('n', ']g', "&diff ? ']g' : '<cmd>Gitsigns next_hunk<CR>'", {expr=true})
          map('n', '[g', "&diff ? '[g' : '<cmd>Gitsigns prev_hunk<CR>'", {expr=true})

          -- Actions
          map('n', '<leader>gr', ':Gitsigns reset_hunk<CR>')
          map('v', '<leader>gr', ':Gitsigns reset_hunk<CR>')
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
      vim.cmd [[
      hi! link GitSignsAdd diffAdded
      hi! link GitSignsChange diffChanged
      hi! link GitSignsDelete diffRemoved
      ]]
    end
  }


  -- colorizer
  use {
    'norcalli/nvim-colorizer.lua',
    config = function()
      require'colorizer'.setup()
    end
  }

  use {
    'romgrk/nvim-treesitter-context',
    config = function()
      require'treesitter-context'.setup{
        enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
        throttle = true, -- Throttles plugin updates (may improve performance)
        max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
        patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
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
      exact_patterns = {
        -- Example for a specific filetype with Lua patterns
        -- Treat patterns.rust as a Lua pattern (i.e "^impl_item$" will
        -- exactly match "impl_item" only)
        -- rust = true, 
      }
    }
    vim.cmd[[hi TreesitterContext guibg=#0D2341]]
  end
  }

  use {
    'akinsho/bufferline.nvim',
    config = function()
      require("bufferline").setup{
        options = {
          separator_style = "slant",
          diagnostics = "nvim_lsp",
          max_name_length = 100,
          name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
            -- remove extension from markdown files for example
            if buf.bufnr == vim.fn.bufnr() then
              return vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
            else
              return buf.name
            end
          end,
          diagnostics_indicator = function(count, level, diagnostics_dict, context)
            local s = " "
            for e, n in pairs(diagnostics_dict) do
              local sym = e == "error" and " "
              or (e == "warning" and "  " or " " )
              s = s .. n .. sym
            end
            return s
          end
        }
      }
    end
  }

  use {
    'stevearc/dressing.nvim',
    config = function()
    end
  }

  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = function()
      local custom_auto = require'lualine.themes.auto'
      custom_auto.normal.a.fg = "#C4CBD7"
      custom_auto.normal.b.fg = "#9CA5B3"
      custom_auto.normal.c.bg = "#21262D"
      custom_auto.inactive = {
        a = { fg = '#c6c6c6', bg = '#080808' },
        b = { fg = '#c6c6c6', bg = '#080808' },
        c = { fg = '#c6c6c6', bg = '#080808' },
      }
      -- lsp info, from https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua
      local lsp_info =  {
        -- Lsp server name .
        function()
          local msg = 'No Active LSP'
          local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
          local clients = vim.lsp.get_active_clients()
          if next(clients) == nil then
            return msg
          end
          for _, client in ipairs(clients) do
            local filetypes = client.config.filetypes
            if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
              return client.name
            end
          end
          if clients[1].name ~= nil then
            return clients[1].name
          else
            return msg
          end
        end,
        icon = ' ',
        color = {gui = 'bold'}
      }

      if vim.g.wait_init ~= 1 then
        vim.defer_fn(function()
          vim.g.wait_init = 1
        end, 500)
      end

      local copilot = function()
        if vim.g.wait_init == 1 then
          if vim.api.nvim_eval("copilot#Enabled()") == 1 then
            return ' '
          else
            return ' '
          end
        else
          return ' '
        end
      end

      local function gtagsHandler()
        if vim.g.gutentags_load == 1 then
          if vim.api.nvim_eval("gutentags#statusline()") == "" then
            return ''
          else
            return "Gtags Indexing..."
          end
        else
          return ''
        end
      end

      local function auto_session_name()
        local status_ok, lib = pcall(require, 'auto-session-library')
        if status_ok then
          return lib.current_session_name
        else
          return ''
        end
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
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {gtagsHandler,{"aerial", sep = " > "}},
          lualine_x = {lsp_info, auto_session_name()},
          lualine_y = { 'fileformat', 'filetype', copilot},
          lualine_z = {'%l/%L,%c', 'encoding' }
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
  }

  use {
    'kevinhwang91/rnvimr',
    keys = "<leader>ra",
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>ra', '<cmd>RnvimrToggle<CR>', { noremap = true, silent = true})
      vim.g.rnvimr_enable_picker = 1
    end
  }

  -- highlight cursor words via lsp
  use {
    'RRethy/vim-illuminate',
    config = function()
      vim.g.Illuminate_delay = 300
      vim.g.Illuminate_ftblacklist = {"NvimTree", "alpha", "dapui_scopes", "dapui_breakpoints", "help"}
      vim.api.nvim_command [[ hi def LspReferenceText guibg=#193b25]]
      vim.api.nvim_command [[ hi def link LspReferenceWrite LspReferenceText ]]
      vim.api.nvim_command [[ hi def link LspReferenceRead LspReferenceText ]]
      vim.api.nvim_command [[ hi link illuminatedWord LspReferenceText ]]
    end
  }

  use {
    'kyazdani42/nvim-tree.lua',
    requires = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icon
    },
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>n', '<cmd>NvimTreeFindFileToggle<CR>', { noremap = true, silent = true})
      vim.g.nvim_tree_git_hl = 1
      require'nvim-tree'.setup {
        disable_netrw = true,
        diagnostics = {
          enable = true,
        },
        view = {
          mappings = {
            list = {
              { key = "K", cb = '5k' },
              { key = "J", cb = '5j' },
              { key = "H", cb = '5h' },
              { key = "<C-h>", action = 'toggle_dotfiles' },
              { key = "=", action = 'cd' },
              { key = "<leader>", action = 'edit' },
            }
          }
        }
      }
    end
  }

  use {
    'famiu/bufdelete.nvim',
    keys = '<leader>x',
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>x', '<cmd>Bdelete!<CR>', { noremap = true, silent = true})
    end
  }

  use {
    'nvim-telescope/telescope-fzf-native.nvim',
    run = 'make',
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
  }

  use {
    'tom-anders/telescope-vim-bookmarks.nvim',
    requires = {{'MattesGroeger/vim-bookmarks'}},
    config = function()
      require('telescope').load_extension('vim_bookmarks')
    end
  }

  use {
    'rmagatti/auto-session',
    config = function()
      require('auto-session').setup {
        log_level = 'info',
        auto_session_suppress_dirs = {'~/'},
        auto_session_create_enabled = false,
        auto_session_enable_last_session = true,
        auto_restore_enabled = false,
      }
    end
  }

  use {
    'goolord/alpha-nvim',
    config = function ()
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

          local file_button_el = file_button(fn, " " .. shortcut, short_fn)
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
        dashboard.button("l", "  Load session", "<cmd> RestoreSession <cr>"),
        dashboard.button("r", "  Open file manager", "<cmd>PackerLoad rnvimr<cr><cmd>RnvimrToggle <cr>"),
        dashboard.button("f", "  Find file", "<cmd>Telescope find_files<CR>"),
        dashboard.button("h", "  Recently opened files", "<cmd> Telescope oldfiles <CR>"),
        dashboard.button("g", "  Find word","<cmd>Telescope live_grep<CR>"),
        dashboard.button("m", "  Jump to bookmarks", "<cmd>Telescope vim_bookmarks<cr>"),
        dashboard.button("u", "  Update plugins" , ":PackerSync<CR>"),
        dashboard.button("q", "  Quit" , ":qa<CR>"),
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
  }

  use {'tversteeg/registers.nvim', opt = false}

  use {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup({

      })
    end
  }

  use {
    "folke/trouble.nvim",
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("trouble").setup {
        action_keys = 
        {
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
  }

  use {
    'phaazon/hop.nvim',
    config = function()
      require'hop'.setup()
      vim.api.nvim_set_keymap('n', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      vim.api.nvim_set_keymap('v', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      vim.api.nvim_set_keymap('n', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
      vim.api.nvim_set_keymap('v', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
    end
  }
  use {
    'folke/which-key.nvim',
    config = function()
      require("which-key").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        window = {
          border = "single"
        }
      }
    end
  }

  use {
    'dstein64/nvim-scrollview',
    config = function()
      vim.g.scrollview_current_only = 1
      vim.g.scrollview_excluded_filetypes = {"NvimTree", "alpha", "dapui_scopes"}
    end
  }

  use {
    'h-hg/fcitx.nvim',
    opt = false,
  }

  -- vim plugins
  use {"dstein64/vim-startuptime", opt = false}
  use {
    'voldikss/vim-translator',
    keys = "<leader>y",
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>y', "<cmd>TranslateW<cr>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap('v', '<leader>y', "<cmd>TranslateW<cr>", { noremap = true, silent = true })
    end
  }
  use {
    'iamcco/markdown-preview.nvim',
    run = "cd app && yarn install",
    ft = {"markdown"},
    config = function()
      vim.g.mkdp_open_to_the_world = 1

      vim.cmd[[
      function! Mkdp_handler(url)
        exec "silent !firefox -new-window " . a:url
      endfunction
      ]]

      vim.g.mkdp_browserfunc = 'Mkdp_handler'
    end
  }
  use {
    'kana/vim-textobj-entire',
    opt = false,
    requires = {{"kana/vim-textobj-user", opt = false}},
  }
  use {
    'lfv89/vim-interestingwords',
    keys = "<leader>h",
    config = function()
      vim.api.nvim_set_keymap('n', '<leader>h', "<cmd>call InterestingWords('n')<cr>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap('v', '<leader>h', "<cmd>call InterestingWords('v')<cr>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>H', "<cmd>call UncolorAllWords()<cr>", { noremap = true, silent = true })
    end
  }
  use {'pgilad/vim-skeletons', }
  use {
    'SirVer/ultisnips',
    requires = {{'honza/vim-snippets', rtp = '.'}},
    config = function()
      vim.g.UltiSnipsExpandTrigger = '<Plug>(ultisnips_expand)'
      vim.g.UltiSnipsJumpForwardTrigger = '<Plug>(ultisnips_jump_forward)'
      vim.g.UltiSnipsJumpBackwardTrigger = '<Plug>(ultisnips_jump_backward)'
      vim.g.UltiSnipsListSnippets = '<c-x><c-s>'
      vim.g.UltiSnipsRemoveSelectModeMappings = 0
      vim.g.UltiSnipsEditSplit="vertical"
      vim.g.UltiSnipsSnippetDirectories={ os.getenv("HOME") .. '/.vim/UltiSnips' }
      vim.api.nvim_set_keymap('n', '<leader>ss', '<cmd>UltiSnipsEdit<cr>', { noremap = true, silent = true })
    end
  }

  use {
    'github/copilot.vim',
    config = function()
      vim.g.copilot_echo_num_completions = 1
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_tab_fallback = ""

      vim.api.nvim_set_keymap('i', '<C-e>', 'copilot#Dismiss()', { noremap = true, silent = true, expr = true })
    end
  }

  use {
    "lambdalisue/suda.vim",
    opt = false,
    config = function()
    end
  }
  use {
    'mbbill/undotree',
    opt = false,
    config = function()
      vim.api.nvim_set_keymap('n', 'U', '<cmd>UndotreeToggle<cr>', { noremap = true, silent = true })
    end
  }
  use {
    'machakann/vim-sandwich',
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
  }

  use {'MTDL9/vim-log-highlighting', }

  use {
    'GustavoKatel/telescope-asynctasks.nvim',
    config = function()
      -- Fuzzy find over current tasks
      vim.cmd[[command! AsyncTaskTelescope lua require("telescope").extensions.asynctasks.all()]]
    end
  }


  use {
    'skywind3000/asynctasks.vim',
    requires = {{'skywind3000/asyncrun.vim'}},
    config = function()
      vim.g.asyncrun_open = 6
      vim.g.asynctasks_term_pos = 'bottom'
      vim.g.asynctasks_term_rows = 14
      vim.api.nvim_set_keymap('n', '<leader>ae', '<cmd>AsyncTaskEdit<cr>', { noremap = true, silent = true })
    end
  }

  use {
    'KabbAmine/vCoolor.vim',
    config = function()
      vim.g.vcoolor_disable_mappings = 1
      vim.api.nvim_set_keymap('n', '<leader>cp', '<cmd>VCoolor<cr>', { noremap = true, silent = true })
    end
  }

  use {
    'tpope/vim-fugitive',
  }

  use {
    'rbong/vim-flog'
  }

  use {
    'mg979/vim-visual-multi',
    config = function()
      vim.g.VM_theme = 'neon'
    end
  }

 --管理gtags，集中存放tags
  use {'ludovicchabant/vim-gutentags', }
  use {
    'skywind3000/gutentags_plus',
    config = function()
      -- enable gtags module
      -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
      vim.g.gutentags_modules = {'gtags_cscope'}

      -- config project root markers.
      vim.g.gutentags_project_root = {'.root', '.svn', '.git', '.hg', '.project', '.exrc'}

      -- generate datebases in my cache directory, prevent gtags files polluting my project
      vim.g.gutentags_cache_dir = os.getenv("HOME") .. '/.cache/tags'

      -- change focus to quickfix window after search (optional).
      vim.g.gutentags_plus_switch = 1

      vim.g.gutentags_load = 1

    end
  }

  -- dap
  use {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require('dap')
      vim.cmd('hi debugRed guifg=red')
      vim.fn.sign_define('DapBreakpoint', {text='🛑', texthl='debugRed', linehl='', numhl=''})
      dap.defaults.fallback.terminal_win_cmd = 'vertical rightbelow 50new'
      vim.cmd [[ au FileType dap-repl lua require('dap.ext.autocompl').attach() ]]

      vim.cmd [[
      "nnoremap <silent> <F2> :lua require'dap'.terminate({},{terminateDebuggee=true},term_dap())<CR>
      nnoremap <silent> <F2> :lua require'dap'.terminate()<CR>
      nnoremap <silent> <F5> :lua require'dap'.continue()<CR>
      nnoremap <silent> <leader><F5> :lua require'dap'.run_to_cursor()<CR>
      nnoremap <silent> <F6> :lua require'dap'.pause()<CR>
      nnoremap <silent> <F10> :lua require'dap'.step_over()<CR>
      nnoremap <silent> <F11> :lua require'dap'.step_into()<CR>
      nnoremap <silent> <F12> :lua require'dap'.step_out()<CR>
      nnoremap <silent> <F9> :lua require'dap'.toggle_breakpoint()<CR>
      nnoremap <silent> <leader><F9> :lua require'dap'.clear_breakpoints()<CR>
      nnoremap <silent> <F7> <Cmd>lua require("dapui").eval()<CR>
      vnoremap <silent> <F7> <Cmd>lua require("dapui").eval()<CR>
      ]]

      -- C/C++
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = vim.fn.stdpath('data') .. '/dapinstall/ccppr_vsc/extension/debugAdapters/bin/OpenDebugAD7',
      }

      --[[
      dap.adapters.codelldb = function(callback, config)
      -- specify in your configuration host = your_host , port = your_port
      callback({ type = "server", host = config.host, port = config.port })
      end
      ]]
      dap.adapters.codelldb = function(on_adapter)
        local stdout = vim.loop.new_pipe(false)
        local stderr = vim.loop.new_pipe(false)

        local cmd = vim.fn.stdpath('data') .. '/dapinstall/ccppr_lldb/extension/adapter/codelldb'

        local handle, pid_or_err
        local opts = {
          stdio = {nil, stdout, stderr},
          detached = true,
        }
        handle, pid_or_err = vim.loop.spawn(cmd, opts, function(code)
          stdout:close()
          stderr:close()
          handle:close()
          if code ~= 0 then
            print("codelldb exited with code", code)
          end
        end)
        assert(handle, "Error running codelldb: " .. tostring(pid_or_err))
        stdout:read_start(function(err, chunk)
          assert(not err, err)
          if chunk then
            local port = chunk:match('Listening on port (%d+)')
            if port then
              vim.schedule(function()
                on_adapter({
                  type = 'server',
                  host = '127.0.0.1',
                  port = port
                })
              end)
            else
              vim.schedule(function()
                require("dap.repl").append(chunk)
              end)
            end
          end
        end)
        stderr:read_start(function(err, chunk)
          assert(not err, err)
          if chunk then
            vim.schedule(function()
              require("dap.repl").append(chunk)
            end)
          end
        end)
      end

      dap.configurations.cpp = {
        {
          name = "Launch file",
          type = "cppdbg",
          -- type = "codelldb",
          request = "launch",
          --[[
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          ]]
          program = "./${fileBasenameNoExtension}",
          cwd = '${workspaceFolder}',
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description =  'enable pretty printing',
              ignoreFailures = false 
            },
          },
        },
        {
          name = "Attach file",
          type = "cppdbg",
          -- type = "codelldb",
          request = "attach",
          --[[
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          ]]
          program = "./${fileBasenameNoExtension}",
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

      -- Python
      dap.adapters.python = {
        type = 'executable';
        command = os.getenv("HOME") .. '/.local/share/nvim/dapinstall/python/bin/python',
        args = { '-m', 'debugpy.adapter' };
      }
      dap.configurations.python = {
        {
          -- The first three options are required by nvim-dap
          type = 'python'; -- the type here established the link to the adapter definition: `dap.adapters.python`
          request = 'launch';
          name = "Launch file";

          -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

          program = "${file}"; -- This configuration will launch the current file if used.
          console = "integratedTerminal";
          pythonPath = function()
            -- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
            -- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
            -- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.
            local cwd = vim.fn.getcwd()
            if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
              return cwd .. '/venv/bin/python'
            elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
              return cwd .. '/.venv/bin/python'
            else
              return '/usr/bin/python'
            end
          end;
        },
      }

      -- Java
      dap.configurations.java = {
        {
          -- You need to extend the classPath to list your dependencies.
          -- `nvim-jdtls` would automatically add the `classPaths` property if it is missing
          -- classPaths = {},

          javaExec = "java",
          --[[
          mainClass = function()
            return vim.fn.input('Main class: ')
          end,
          ]]

          -- If using the JDK9+ module system, this needs to be extended
          -- `nvim-jdtls` would automatically populate this property
          modulePaths = {},
          name = "Launch Java Debug",
          request = "launch",
          type = "java"
        },
      }

      -- Dap load launch.json from vscode when avaliable
      if vim.fn.filereadable("./.vscode/launch.json") and vim.g.load_launchjs ~= 1 then
        require('dap.ext.vscode').load_launchjs()
        vim.g.load_launchjs = 1
      end
    end
  }
  use {
    "rcarriga/nvim-dap-ui",
    requires = {{"mfussenegger/nvim-dap"}},
    config = function()
      local dapui = require("dapui")
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸" },
        mappings = {
          -- Use a table to apply multiple mappings
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
        },
        sidebar = {
          -- You can change the order of elements in the sidebar
          elements = {
            -- Provide as ID strings or tables with "id" and "size" keys
            {
              id = "scopes",
              size = 0.25, -- Can be float or integer > 1
            },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 00.25 },
          },
          size = 40,
          position = "left", -- Can be "left", "right", "top", "bottom"
        },
        tray = {
          elements = { "repl" },
          size = 10,
          position = "bottom", -- Can be "left", "right", "top", "bottom"
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

    end
  }
  use {
    'theHamsta/nvim-dap-virtual-text',
    requires = {{"mfussenegger/nvim-dap"}},
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
  }

  use {
    'Pocco81/DAPInstall.nvim',
    config = function()
      local dap_install = require("dap-install")

      dap_install.setup({
        installation_path = vim.fn.stdpath("data") .. "/dapinstall/",
      })

    end
  }

end,
config = {
  compile_path = require 'packer.util'.join_paths(vim.fn.stdpath('config'), 'packer_compiled.lua'),
  package_root   = require 'packer.util'.join_paths(vim.fn.stdpath('data'), 'plugins', 'pack'),
  opt_default = true,
}})

-----------------------------dap------------------------------------------------------
function term_dap()
  local dapui = require("dapui")
  dapui.close()
  local virtual_text = require 'nvim-dap-virtual-text/virtual_text'
  virtual_text._on_continue()
  virtual_text.clear_last_frames()
end
--------------------------------------------------------------------------------------

----------------------------Lazy Load-------------------------------------------------
function lazyLoadPlugins()
  -- begin basic
  require('packer').loader('plenary.nvim', '<bang>' == '!')
  require('packer').loader('nvim-web-devicons', '<bang>' == '!')
  -- end basic

  -- begin telescope
  require('packer').loader('telescope.nvim', '<bang>' == '!')
  require('packer').loader('project.nvim', '<bang>' == '!')
  require('packer').loader('telescope-fzf-native.nvim', '<bang>' == '!')
  require('packer').loader('telescope-vim-bookmarks.nvim', '<bang>' == '!')
  -- end telescope

  -- begin LSP & CMP
  require('packer').loader('formatter.nvim', '<bang>' == '!')
  require('packer').loader('nvim-cmp', '<bang>' == '!')
  require('packer').loader('ultisnips cmp-nvim-ultisnips vim-snippets', '<bang>' == '!')
  require('packer').loader('cmp-nvim-lsp cmp-nvim-lua cmp-path cmp-buffer cmp-omni cmp-dictionary', '<bang>' == '!')
  require('packer').loader('nvim-lsp-installer', '<bang>' == '!')
  require('packer').loader('nvim-lspconfig nvim-jdtls', '<bang>' == '!')
  require('packer').loader('lsp_signature.nvim', '<bang>' == '!')
  require('packer').loader('fidget.nvim', '<bang>' == '!')
  require('packer').loader('nvim-lightbulb', '<bang>' == '!')
  require('packer').loader('trouble.nvim', '<bang>' == '!')
  require('packer').loader('copilot.vim', '<bang>' == '!')
  require('packer').loader('vim-illuminate', '<bang>' == '!')
  -- end LSP & CMP

  -- begin treesitter (slow performance)
  require('packer').loader('nvim-treesitter', '<bang>' == '!')
  require('packer').loader('nvim-treesitter-context', '<bang>' == '!')
  require('packer').loader('nvim-ts-rainbow', '<bang>' == '!')   -- performance issue
  require('packer').loader('indent-blankline.nvim', '<bang>' == '!')
  require('packer').loader('nvim-treesitter-textobjects', '<bang>' == '!')
  require('packer').loader('nvim-ts-autotag', '<bang>' == '!')
  -- end treesitter

  -- begin misc
  require('packer').loader('nvim-autopairs', '<bang>' == '!')
  require('packer').loader('vim-sandwich', '<bang>' == '!')
  require('packer').loader('vim-visual-multi', '<bang>' == '!')
  require('packer').loader('auto-session', '<bang>' == '!')
  require('packer').loader('bufdelete.nvim', '<bang>' == '!')
  require('packer').loader('aerial.nvim', '<bang>' == '!')
  require('packer').loader('Comment.nvim', '<bang>' == '!')
  require('packer').loader('hop.nvim', '<bang>' == '!')
  require('packer').loader('which-key.nvim', '<bang>' == '!')
  require('packer').loader('asynctasks.vim asyncrun.vim telescope-asynctasks.nvim', '<bang>' == '!')
  -- end misc

  -- begin git
  require('packer').loader('gitsigns.nvim', '<bang>' == '!')
  require('packer').loader('vim-fugitive', '<bang>' == '!')
  require('packer').loader('vim-flog', '<bang>' == '!')
  -- end git

  -- begin UI
  require('packer').loader('lualine.nvim', '<bang>' == '!')
  require('packer').loader('bufferline.nvim', '<bang>' == '!')
  require('packer').loader('nvim-colorizer.lua', '<bang>' == '!')
  require('packer').loader('vCoolor.vim', '<bang>' == '!')
  require('packer').loader('vim-log-highlighting', '<bang>' == '!')
  require('packer').loader('alpha-nvim', '<bang>' == '!')
  require('packer').loader('nvim-tree.lua', '<bang>' == '!')
  require('packer').loader('nvim-scrollview', '<bang>' == '!')
  require('packer').loader('nvim-hlslens', '<bang>' == '!')
  require('packer').loader('dressing.nvim', '<bang>' == '!')
  -- end UI

  -- begin DAP
  require('packer').loader('nvim-dap', '<bang>' == '!')
  require('packer').loader('nvim-dap-ui', '<bang>' == '!')
  require('packer').loader('nvim-dap-virtual-text', '<bang>' == '!')
  require('packer').loader('DAPInstall.nvim', '<bang>' == '!')
  -- end DAP
end
--------------------------------------------------------------------------------------
----------------------------Constant Plugins------------------------------------------

function _G.qftf(info)
  local items
  local ret = {}
  if info.quickfix == 1 then
    items = vim.fn.getqflist({id = info.id, items = 0}).items
  else
    items = vim.fn.getloclist(info.winid, {id = info.id, items = 0}).items
  end
  local limit = 31
  local fname_fmt1, fname_fmt2 = '%-' .. limit .. 's', '…%.' .. (limit - 1) .. 's'
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
        if #fname <= limit then
          fname = fname_fmt1:format(fname)
        else
          fname = fname_fmt2:format(fname:sub(1 - limit))
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

-- vim.api.nvim_set_var("suda_smart_edit", 1)

local autosave = require("autosave")

autosave.setup({
  enabled = true,
  --execution_message = "AutoSave: saved at " .. vim.fn.strftime("%H:%M:%S"),
  execution_message = '',
  events = {"InsertLeave", "TextChanged"},
  -- events = {"CursorHold", "FocusLost", "BufLeave"},
  conditions = {
    exists = true,
    filename_is_not = {},
    filetype_is_not = {},
    modifiable = true
  },
  write_all_buffers = false,
  on_off_commands = true,
  clean_command_line_interval = 0,
  debounce_delay = 135
})

function loadGtags()
  require('packer').loader('vim-gutentags gutentags_plus', '<bang>' == '!')
  vim.cmd("edit %")
end
vim.cmd("command! LoadGtags lua loadGtags()")

-- auto load vim-skeletons
vim.cmd [[
function! LoadSkeletons()
  packadd ultisnips
  packadd vim-skeletons
  call skeletons#InsertSkeleton()
endfunction

let g:skeletons#autoRegister = 1
let g:skeletons#skeletonsDir = "~/.vim/skeletons"
autocmd BufNewFile * call LoadSkeletons()
]]

-- register.nvim
vim.g.registers_window_border = "single"

-- vCoolor.vim won't disable mappings if it is loaded after the plugin
vim.g.vcoolor_disable_mappings = 1
-- same as interesting words
vim.g.interestingWordsDefaultMappings = 0
--------------------------------------------------------------------------------------
if vim.fn.expand('%:t') == '.nvimrc.lua' then
  vim.api.nvim_set_keymap('n', '<leader>wq', '<cmd>source %<cr> <cmd>PackerCompile<CR>', { noremap = true, silent = false })
  -- vim.cmd[[ au BufWritePost .nvimrc.lua source % | PackerCompile ]]
end
