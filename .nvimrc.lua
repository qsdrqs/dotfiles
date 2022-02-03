--
--           | \ | | ___  __\ \   / /_ _|  \/  |     | |  | | | | / \
--           |  \| |/ _ \/ _ \ \ / / | || |\/| |     | |  | | | |/ _ \
--           | |\  |  __/ (_) \ V /  | || |  | |  _  | |__| |_| / ___ \
--           |_| \_|\___|\___/ \_/  |___|_|  |_| (_) |_____\___/_/   \_\
--------------------------------------------------------------------------------------

-- vim.cmd [[packadd packer.nvim]]
local fn = vim.fn
local install_path = fn.stdpath('data')..'/plugins/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

require('packer').startup({function(use)
  -- Packer can manage itself
  use {'wbthomason/packer.nvim'}
  use {'nvim-lua/plenary.nvim' }
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} },
    config = function()
      require('telescope').setup {
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            }
          }
        }
      }

      vim.api.nvim_set_keymap('n', '<leader>f', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>b', '<cmd>Telescope buffers<cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>rg', '<cmd>Telescope grep_string <cr>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>Telescope builtin include_extensions=true <cr>', { noremap = true, silent = true })
      -- print("Telescope loaded")
    end
  }

  use {
    'kevinhwang91/nvim-bqf',
  } -- better quick fix

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
          '-jar', os.getenv("HOME") .. "/.local/share/nvim/lsp_servers/jdtls/plugins/org.eclipse.equinox.launcher_1.6.400.v20210924-0641.jar",
          -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
          -- Must point to the                                                     Change this to
          -- eclipse.jdt.ls installation                                           the actual version


          -- 💀
          '-configuration', os.getenv("HOME") .. '/.local/share/nvim/lsp_servers/jdtls/config_linux',
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
            vim.fn.glob(os.getenv("HOME") .. "/.local/share/nvim/dapinstall/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.35.0.jar")
          }
        },

        on_attach = function(client, bufnr)
          -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
          -- you make during a debug session immediately.
          -- Remove the option if you do not want that.
          require('jdtls').setup_dap({ hotcodereplace = 'auto' })
          require("aerial").on_attach(client, bufnr)
          lsp_map()
        end,
      }
      vim.cmd[[ autocmd FileType java lua require('jdtls').start_or_attach(jdt_config)]]
    end
  }

  use {
    'neovim/nvim-lspconfig',
    config = function()
      local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

      local lspconfig = require('lspconfig')

      function lsp_map(client, bufnr)
        local opts = { noremap=true, silent=true }
        -- Enable completion triggered by <c-x><c-o>
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

        -- Mappings.
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'v', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
        vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gh', '<cmd>ClangdSwitchSourceHeader <CR>', opts)
      end

      lspconfig["pyright"].setup {
        cmd = {os.getenv("HOME") .. "/.local/share/nvim/lsp_servers/python/node_modules/.bin/pyright-langserver", "--stdio"},
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          require("aerial").on_attach(client, bufnr)
          lsp_map()
        end,
        flags = {
          -- This will be the default in neovim 0.7+
          debounce_text_changes = 150,
        },
      }

      lspconfig["texlab"].setup {
        cmd = {os.getenv("HOME") .. "/.local/share/nvim/lsp_servers/latex/texlab"},
        filetypes = { "tex", "bib" },
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          require("aerial").on_attach(client, bufnr)
          lsp_map()
        end,
        flags = {
          -- This will be the default in neovim 0.7+
          debounce_text_changes = 150,
        },
        settings = {
          texlab = {
            build = {
              onSave = true -- Automatically build latex on save
            }
          },
          chktex = {
            onEdit = false,
            onOpenAndSave = true
          }
        },
        handlers = {
          ["textDocument/publishDiagnostics"] = vim.lsp.with(
          vim.lsp.diagnostic.on_publish_diagnostics, {
            -- Disable virtual_text
            virtual_text = false,
          }),
        },
      }

      local servers = { 'clangd' }
      for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup {
          -- on_attach = my_custom_on_attach,
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            require("aerial").on_attach(client, bufnr)
            lsp_map()
          end,
          flags = {
            -- This will be the default in neovim 0.7+
            debounce_text_changes = 150,
          },
        }
      end

      local opts = { noremap=true, silent=true }
      vim.api.nvim_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
      vim.api.nvim_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
      vim.api.nvim_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
      vim.api.nvim_set_keymap('n', '<space>q', '<cmd>lua vim.diagnostic.setloclist()<CR>', opts)


      vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
      vim.lsp.diagnostic.on_publish_diagnostics, {
        -- Disable signs
      })

      -- vim.cmd [[au CursorHold <buffer> lua vim.diagnostic.open_float()]]
    end
  }
  
  use {'kyazdani42/nvim-web-devicons'}
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require("nvim-treesitter.configs").setup {
        highlight = {
          -- ...
        },
        -- ...
        rainbow = {
          enable = true,
          disable = { }, -- list of languages you want to disable the plugin for
          extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
          max_file_lines = nil, -- Do not enable for files with more than n lines, int
          colors = {'#FF0000', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#FF00FF'}, -- table of hex strings
          -- termcolors = {} -- table of colour name strings
        }
      }

      require 'nvim-treesitter.configs'.setup {
        -- One of "all", "maintained" (parsers with maintainers), or a list of languages
        ensure_installed = "maintained",

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

    end

  }

  use {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup{}
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
      vim.api.nvim_set_keymap("n", "<leader>af", ":lua formatBuf()<cr>", {noremap = true, silent = true})
    end
  }

  -- complete
  use { 'quangnguyen30192/cmp-nvim-ultisnips', opt = true  }
  use { 'hrsh7th/cmp-nvim-lsp',  }
  -- use { 'hrsh7th/cmp-vsnip',  }
  -- use { 'hrsh7th/vim-vsnip',  }
  use { 'hrsh7th/cmp-nvim-lua',  }
  use { 'hrsh7th/cmp-buffer',  }
  use { 'hrsh7th/cmp-cmdline',  }
  use { 'hrsh7th/cmp-omni',  }

  use {
    'ray-x/lsp_signature.nvim',
    config = function()
      require "lsp_signature".setup({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
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

      cmp.setup{

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
          { name = 'omni' },
          { name = 'nvim_lsp' },
          -- { name = 'vsnip' }, -- For vsnip users.
          { name = 'nvim_lua' },
          { name = 'buffer' },
          -- { name = 'luasnip' }, -- For luasnip users.
          -- { name = 'snippy' }, -- For snippy users.
        }),

        completion = {
          completeopt = 'menu,menuone,noinsert'
        }

      }

      vim.api.nvim_set_keymap('n', '<leader>s', '<cmd>UltiSnipsEdit<cr>', { noremap = true, silent = true })
      -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
      --[[
      cmp.setup.cmdline('/', {
      sources = {
      { name = 'buffer' }
      },
      })
      ]]

      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        }),

      })
    end
  }
  use {
    'SirVer/ultisnips',
    requires = {{'honza/vim-snippets', rtp = '.'}},
    opt = true,
    config = function()
      vim.g.UltiSnipsExpandTrigger = '<Plug>(ultisnips_expand)'
      vim.g.UltiSnipsJumpForwardTrigger = '<Plug>(ultisnips_jump_forward)'
      vim.g.UltiSnipsJumpBackwardTrigger = '<Plug>(ultisnips_jump_backward)'
      vim.g.UltiSnipsListSnippets = '<c-x><c-s>'
      vim.g.UltiSnipsRemoveSelectModeMappings = 0
      vim.g.UltiSnipsEditSplit="vertical"
      vim.g.UltiSnipsSnippetDirectories={ os.getenv("HOME") .. '/.vim/UltiSnips' }
    end
  }


  use {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      vim.cmd [[
      highlight IndentBlanklineContextChar guifg=#FFFF00 gui=nocombine
      highlight IndentBlanklineContextStart guisp=#FFFF00 gui=underline
      let g:indent_blankline_use_treesitter = v:false
      let g:indent_blankline_show_first_indent_level = v:false
      ]]
      require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
      }
    end
  }
  use {"p00f/nvim-ts-rainbow",}

  -- cd to project root
  use {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup {
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", ".root" },
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
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>v', '<cmd>AerialToggle!<CR>', {})
      require('telescope').load_extension('aerial')
      require("aerial").setup({
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
    opt = true,
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
  end
}

  -- vim plugins
  use {
    'Lucklyric/copilot.vim',
    opt = true,
    config = function()
      vim.g.copilot_echo_num_completions = 1
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_tab_fallback = ""
    end
  }

  use {
    "lambdalisue/suda.vim",
    config = function()
    end
  }
  use {
    'mbbill/undotree',
    config = function()
      vim.api.nvim_set_keymap('n', 'U', '<cmd>UndotreeToggle<cr>', { noremap = true, silent = true })
    end
  }
  use {
    'machakann/vim-sandwich',
    config = function()
      vim.cmd[[
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
  use 'sakshamgupta05/vim-todo-highlight'

  use {
    'skywind3000/asynctasks.vim',
    opt = true,
    requires = {{'skywind3000/asyncrun.vim'}},
    config = function()
      vim.g.asyncrun_open = 6
      vim.g.asynctasks_term_pos = 'bottom'
      vim.g.asynctasks_term_rows = 14
    end
  }

  use {
    'KabbAmine/vCoolor.vim',
    opt = true,
    config = function()
      vim.g.vcoolor_disable_mappings = 1
      vim.api.nvim_set_keymap('n', '<leader>cp', '<cmd>VCoolor<cr>', { noremap = true, silent = true })
    end
  }

  use {
    'tpope/vim-fugitive',
    opt = true,
  }

 --管理gtags，集中存放tags
  use {'ludovicchabant/vim-gutentags', opt = true}
  use {
    'skywind3000/gutentags_plus',
    opt = true,
    config = function()
      -- enable gtags module
      -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
      vim.g.gutentags_modules = {'gtags_cscope'}

      -- config project root markers.
      vim.g.gutentags_project_root = {'.root', '.svn', '.git', '.hg', '.project'}

      -- generate datebases in my cache directory, prevent gtags files polluting my project
      vim.g.gutentags_cache_dir = os.getenv("HOME") .. '/.cache/tags'

      -- change focus to quickfix window after search (optional).
      vim.g.gutentags_plus_switch = 1
      vim.cmd("set statusline+=%{gutentags#statusline()}")
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
      nnoremap <silent> <F2> :lua require'dap'.terminate({},{terminateDebuggee=true},term_dap())<CR>
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
        type = 'executable',
        command = os.getenv("HOME") .. '/.local/share/nvim/dapinstall/ccppr_vsc/extension/debugAdapters/bin/OpenDebugAD7',
      }

      dap.configurations.cpp = {
        {
          name = "Launch file",
          type = "cppdbg",
          request = "launch",
          --[[
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          ]]
          program = "./${fileBasenameNoExtension}",
          cwd = '${workspaceFolder}',
          stopOnEntry = true,
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description =  'enable pretty printing',
              ignoreFailures = false 
            },
          },
        },
      }
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.rust = dap.configurations.cpp

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

      -- print("DAP loaded")

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

  if packer_bootstrap then
    require('packer').sync()
  end

end,
config = {
  profile = {
    enable = true
  },
  compile_path = require 'packer.util'.join_paths(vim.fn.stdpath('config'), 'packer_compiled.lua'),
  package_root   = require 'packer.util'.join_paths(vim.fn.stdpath('data'), 'plugins', 'pack'),
  opt_default = false,
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
  require('packer').loader('copilot.vim', '<bang>' == '!')
  require('packer').loader('ultisnips cmp-nvim-ultisnips vim-snippets', '<bang>' == '!')
  require('packer').loader('asynctasks.vim asyncrun.vim', '<bang>' == '!')
  require('packer').loader('vCoolor.vim', '<bang>' == '!')
  require('packer').loader('vim-fugitive', '<bang>' == '!')
  require('packer').loader('nvim-treesitter-context', '<bang>' == '!')
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

function formatBuf()

  if not vim.g.loadplugins then
    return
  end

  local modes = {"i", "s"}
  local mode = vim.api.nvim_eval("mode()")
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
  vim.lsp.buf.formatting()
end

function loadGtags()
  require('packer').loader('vim-gutentags gutentags_plus', '<bang>' == '!')
  vim.cmd("edit %")
end
vim.cmd("command! LoadGtags lua loadGtags()")



-- defer 1000 ms for formatters
-- vim.cmd[[ au BufWritePost <buffer> silent lua vim.defer_fn(formatBuf, 1000) ]]

--------------------------------------------------------------------------------------
vim.api.nvim_set_keymap('n', '<leader>wq', '<cmd>source %<cr> <cmd>PackerCompile<CR>', { noremap = true, silent = true })
