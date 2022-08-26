--
--           | \ | | ___  __\ \   / /_ _|  \/  |     | |  | | | | / \
--           |  \| |/ _ \/ _ \ \ / / | || |\/| |     | |  | | | |/ _ \
--           | |\  |  __/ (_) \ V /  | || |  | |  _  | |__| |_| / ___ \
--           |_| \_|\___|\___/ \_/  |___|_|  |_| (_) |_____\___/_/   \_\
--------------------------------------------------------------------------------------

-- vim.cmd [[packadd packer.nvim]]
local status_ok, impatient = pcall(require, "impatient")
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

      vim.keymap.set('n', '<leader>f', '<cmd>lua require"telescope.builtin".find_files{no_ignore=true}<cr>', { silent = true })
      vim.keymap.set('n', '<leader>b', '<cmd>Telescope buffers<cr>', { silent = true })
      vim.keymap.set('n', '<leader>gs', '<cmd>Telescope grep_string <cr>', { silent = true })
      vim.keymap.set('n', '<leader>gg', '<cmd>Telescope live_grep <cr>', { silent = true })
      vim.keymap.set('n', '<leader>t', '<cmd>Telescope builtin include_extensions=true <cr>', { silent = true })
      vim.keymap.set('n', '<leader>rc', '<cmd>Telescope command_history <cr>', { silent = true })
      vim.keymap.set('n', '<leader>rf', '<cmd>Telescope lsp_document_symbols<cr>', { silent = true })
      vim.keymap.set('n', '<leader>rl', '<cmd>Telescope current_buffer_fuzzy_find fuzzy=false <cr>', { silent = true })
    end
  }

  use {
    'nvim-telescope/telescope-rg.nvim',
    opt = true,
    keys = "<leader>gG",
    config = function()
      vim.keymap.set('n', '<leader>gG', '<cmd>lua require("telescope").extensions.live_grep_raw.live_grep_raw()<cr>', { silent = true })
    end
  }


  use {
    'kevinhwang91/nvim-bqf',
    opt = false,
  } -- better quick fix

  use {
    'kevinhwang91/nvim-hlslens',
    opt = true,
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
        nearest_float_when = 'auto'
      }
    end
  }

  use {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end
  }

  use {
    'mfussenegger/nvim-jdtls',
    after = 'nvim-lspconfig',
    config = function()
      -- compatible with fidget
      local function progress_report(_, result, ctx)
        local lsp = vim.lsp
        local info = {
          client_id = ctx.client_id,
        }

        local kind = "report"
        if result.complete then
          kind = "end"
        elseif result.workDone == 0 then
          kind = "begin"
        elseif result.workDone > 0 and result.workDone < result.totalWork then
          kind = "report"
        else
          kind = "end"
        end

        local percentage = 0
        if result.totalWork > 0 and result.workDone >= 0 then
          percentage = result.workDone / result.totalWork * 100
        end

        local msg = {
          token = result.id,
          value = {
            kind = kind,
            percentage = percentage,
            title = result.subTask,
            message = result.subTask,
          },
        }
        local client = vim.lsp.get_client_by_id(info.client_id)
        if msg.token and client then
          client.messages.progress[msg.token] = client.messages.progress[msg.token] or {}
        end
        -- print(vim.inspect(result.subTask))
        if result.subTask and result.subTask ~= "" then
          lsp.handlers["$/progress"](nil, msg, info)
        end
      end

      -- java
      local jdt_config = lsp_common_config
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
        }
      }

      -- progress_report
      jdt_config.handlers = {
        ["language/progressReport"] = progress_report,
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
      jdt_config.init_options = {
        bundles = {
          vim.fn.glob(vim.fn.stdpath('data') .. "/mason/packages/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar")
        }
      }

      jdt_config.on_attach = function(client, bufnr)
        -- With `hotcodereplace = 'auto' the debug adapter will try to apply code changes
        -- you make during a debug session immediately.
        -- Remove the option if you do not want that.
        require('jdtls').setup_dap({ hotcodereplace = 'auto' })
        common_on_attach(client,bufnr)
      end
      -- vim.cmd[[ autocmd FileType java lua require('jdtls').start_or_attach(jdt_config)]]
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function()
          require('jdtls').start_or_attach(jdt_config)
        end
      })
    end
  }

  use {
    'neovim/nvim-lspconfig',
    config = function()
      -- vim.lsp.set_log_level('trace')
      vim.lsp.set_log_level('ERROR')

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

        -- Enable completion triggered by <c-x><c-o>
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
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

      -- Mappings.
      -- See `:help vim.lsp.*` for documentation on any of the below functions
      vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
      -- vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      -- vim.keymap.set('n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
      -- vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
      vim.keymap.set('n', 'gr', '<cmd>Trouble lsp_references<CR>', opts)
      vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
      vim.keymap.set('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
      vim.keymap.set('n', '<space>aa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
      vim.keymap.set('n', '<space>ar', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
      vim.keymap.set('n', '<space>al', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
      vim.keymap.set('n', '<space>D', '<cmd>Trouble lsp_type_definitions<CR>', opts)
      vim.keymap.set('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
      vim.keymap.set('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
      vim.keymap.set('n', 'gh', '<cmd>ClangdSwitchSourceHeader <CR>', opts)

      vim.diagnostic.config({
        virtual_text = true,
        virtual_lines = false
      })
      virtualLineEnabled = false

      function ChangeDiagnostic()
        if virtualLineEnabled == false then
          vim.diagnostic.config({
            virtual_text = false,
            virtual_lines = true
          })
          virtualLineEnabled = true
        else
          vim.diagnostic.config({
            virtual_text = true,
            virtual_lines = false
          })
          virtualLineEnabled = false
        end
      end

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

      local servers = { 'clangd', 'pyright', 'texlab', 'sumneko_lua', 'rust_analyzer', 'vimls', 'hls' }
      for _, lsp in ipairs(servers) do
        local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
        lsp_common_config = {
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
            ["textDocument/codeLens"] = function(err, result, ctx, _)
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
            end,
            ["textDocument/hover"] =  vim.lsp.with(vim.lsp.handlers.hover, {border = border}),
            ["textDocument/signatureHelp"] =  vim.lsp.with(vim.lsp.handlers.signature_help, {border = border }),
          }
        }

        if lsp == 'pyright' then lsp_common_config.cmd = {vim.fn.stdpath('data') .. "/mason/bin/pyright-langserver", "--stdio"}
        elseif lsp == 'pylsp' then lsp_common_config.cmd = {'pylsp'}
        elseif lsp == 'clangd' then
          -- set offset encoding
          capabilities.offsetEncoding = 'utf-8'
        elseif lsp == "rust_analyzer" then
          lsp_common_config.cmd = {vim.fn.stdpath('data') .. "/mason/bin/rust-analyzer"}
          -- set offset encoding
          capabilities.offsetEncoding = nil
        elseif lsp == 'vimls' then lsp_common_config.cmd = {vim.fn.stdpath('data') .. "/mason/bin/vim-language-server", "--stdio"}
        elseif lsp == 'hls' then
          lsp_common_config.on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
            vim.cmd [[ autocmd InsertLeave,TextChanged <buffer> lua vim.lsp.codelens.refresh() ]]
            vim.lsp.codelens.refresh()
          end
        elseif lsp == "texlab" then
          lsp_common_config.cmd = {vim.fn.stdpath('data') .. "/mason/bin/texlab" }
          lsp_common_config.on_attach = function(client, bufnr)
            common_on_attach(client,bufnr)
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>v', '<cmd>TexlabForward<cr>', { noremap=true, silent=true })
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>b', '<cmd>TexlabBuild<cr>', { noremap=true, silent=true })
          end
          lsp_common_config.settings = {
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
        elseif lsp == "sumneko_lua" then
          local runtime_path = vim.split(package.path, ';')
          table.insert(runtime_path, "lua/?.lua")
          table.insert(runtime_path, "lua/?/init.lua")

          lsp_common_config.cmd = {vim.fn.stdpath('data') .. "/mason/bin/lua-language-server"}
          if vim.fn.expand('%') == '.nvimrc.lua' then
            lsp_common_config.autostart = false
          end
          lsp_common_config.settings = {
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

        lspconfig[lsp].setup(lsp_common_config)
      end


      vim.keymap.set('n', '<space>e', '<cmd>lua ChangeDiagnostic()<CR>', opts)
      -- vim.keymap.set('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
      vim.keymap.set('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
      vim.keymap.set('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
      vim.keymap.set('n', '<space>Q', '<cmd>TroubleToggle document_diagnostics<CR>', opts)
      vim.keymap.set('n', '<space>q', '<cmd>TroubleToggle workspace_diagnostics<CR>', opts)
      vim.keymap.set('n', '<leader>d', '<cmd>lua showDocument()<CR>', opts)



      -- vim.cmd [[au CursorHold <buffer> lua vim.diagnostic.open_float()]]

      -- UI Customization
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
      vim.keymap.set('n', '<leader>cl', '<cmd>lua vim.lsp.codelens.run()<CR>', opts)
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
    "Pocco81/auto-save.nvim",
    commit = '8df684bcb3c5fff8fa9a772952763fc3f6eb75ad',
    opt = false,
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
      vim.keymap.set("n", "<leader>af", "<cmd>lua formatBuf('n')<CR>", { silent = true })
      vim.keymap.set("v", "<leader>af", "<cmd>lua formatBuf('v')<CR>", { silent = true })

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
          vim.lsp.buf.format{ async = true }
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
  use { 'quangnguyen30192/cmp-nvim-ultisnips', opt = true }
  use { 'hrsh7th/cmp-nvim-lsp',  }
  -- use { 'hrsh7th/cmp-vsnip',  }
  use { 'hrsh7th/vim-vsnip',  }
  use { 'hrsh7th/cmp-nvim-lua',  }
  use { 'hrsh7th/cmp-path', }
  use { 'hrsh7th/cmp-buffer',  }
  use { 'hrsh7th/cmp-omni',  }
  use { 'hrsh7th/cmp-nvim-lsp-signature-help', }
  use {
    'uga-rosa/cmp-dictionary',
    config = function()
      require("cmp_dictionary").setup({ dic = { ["markdown,tex,text"] = { "/usr/share/dict/words" } }, })
      require("cmp_dictionary").update()
    end
  }
  use {
    'hrsh7th/cmp-cmdline',
    opt = true,
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
        floating_window = false,
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
        TypeParameter = "",
        TabNine = ""
      }

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
            vim_item.kind = string.format('%s', kind_icons[vim_item.kind]) -- This concatonates the icons with the name of the item kind
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
            vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.

            -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
            -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
          end,
        },
        mapping = cmp.mapping.preset.insert {
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
              local copilot_keys = vim.fn["copilot#Accept"]()
              if cmp.visible() then
                -- cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
                cmp.confirm()
              elseif copilot_keys ~= "" then
                vim.api.nvim_feedkeys(copilot_keys, "i", true)
              elseif vim.fn["vsnip#jumpable"](1) == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(vsnip-jump-next)"), 'm', true)
              elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(ultisnips_jump_forward)"), 'm', true)
              else
                vim.api.nvim_feedkeys(t("<Tab>"), "n", true)
                -- fallback()
              end
            end,
            s = function(fallback)
              if vim.fn["vsnip#jumpable"](1) == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(vsnip-jump-next)"), 'm', true)
              elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
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
              elseif vim.fn["vsnip#jumpable"](-1) == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(vsnip-jump-prev)"), 'm', true)
              elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
                return vim.api.nvim_feedkeys( t("<Plug>(ultisnips_jump_backward)"), 'm', true)
              else
                fallback()
              end
            end,
            s = function(fallback)
              if vim.fn["vsnip#jumpable"](-1) == 1 then
                vim.api.nvim_feedkeys(t("<Plug>(vsnip-jump-prev)"), 'm', true)
              elseif vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
                return vim.api.nvim_feedkeys( t("<Plug>(ultisnips_jump_backward)"), 'm', true)
              else
                fallback()
              end
            end
          }),
        },
        sources = cmp.config.sources({
          { name = 'ultisnips' }, -- For ultisnips users.
          { name = 'nvim_lsp_signature_help' },
          { name = 'nvim_lsp' },
          -- { name = 'omni' },
          { name = 'dictionary', keyword_length = 2 },
          { name = 'path' },
          -- { name = 'vsnip' }, -- For vsnip users.
          { name = 'nvim_lua' },
          { name = 'buffer' },
          -- { name = 'luasnip' }, -- For luasnip users.
          -- { name = 'snippy' }, -- For snippy users.
        }),

        completion = {
          -- autocomplete = true,
          completeopt = 'menu,menuone,noinsert'
        },

      }

      -- vim.keymap.set('i', '<C-x><C-o>', '<Cmd>lua require("cmp").complete()<CR>', { silent = true })
      vim.cmd[[ command! CmpDisable lua require('cmp').setup{enabled=false} ]]
      vim.cmd[[ command! CmpEnable lua require('cmp').setup{enabled=true} ]]
    end
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      if vim.b.treesitter_disable ~= 1 then
        -- folds by treesitter
        vim.cmd[[ set foldmethod=expr ]]
        vim.o.foldexpr="nvim_treesitter#foldexpr()"

        require 'nvim-treesitter.configs'.setup {
          -- One of "all", or a list of languages
          ensure_installed = {"c", "cpp", "lua", "vim"},

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
          },
          indent = {
            enable = false
          },
        }

        -- disable comment hightlight (for javadoc)
        require"nvim-treesitter.highlight".set_custom_captures {
          -- Highlight the @foo.bar capture group with the "Identifier" highlight group.
          ["comment"] = "NONE",
        }
      end

    end

  }

  use {
    'nvim-treesitter/playground',
    opt = true,
    cmd = {"TSPlaygroundToggle"},
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
    opt = true,
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
    opt = true,
    -- TODO: start highlight list
    config = function()
      if vim.g.colors_name == 'ghdark' then
        vim.cmd [[
        highlight IndentBlanklineContextStart guisp=#79C0FF gui=underline

        highlight link IndentBlanklineIndent1 PreProc
        highlight IndentBlanklineIndent2 guifg=#56D364 gui=nocombine
        highlight link IndentBlanklineIndent3 Type
        highlight link IndentBlanklineIndent4 Keyword
        highlight IndentBlanklineIndent5 guifg=#FF9BCE gui=nocombine
        highlight link IndentBlanklineIndent6 Function
        ]]
      else
        vim.cmd [[
        highlight IndentBlanklineContextStart guisp=#0969DA gui=underline

        highlight IndentBlanklineIndent1 guifg=#0969DA gui=nocombine
        highlight IndentBlanklineIndent2 guifg=#1A7F37 gui=nocombine
        highlight IndentBlanklineIndent3 guifg=#9A6700 gui=nocombine
        highlight IndentBlanklineIndent4 guifg=#CF222E gui=nocombine
        highlight IndentBlanklineIndent5 guifg=#BF3989 gui=nocombine
        highlight IndentBlanklineIndent6 guifg=#8250DF gui=nocombine
        ]]
      end
      local ok, treesitter = pcall(require, 'nvim-treesitter')
      if vim.b.treesitter_disable ~= 1 then
        vim.g.indent_blankline_show_current_context = true
        vim.g.indent_blankline_show_current_context_start = true
      end
      require("indent_blankline").setup {
        -- char = '▏',
        -- context_char = '▏',
        use_treesitter = false,
        space_char_blankline = " ",
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
    opt = true,
    config = function()
      if vim.g.colors_name == 'ghdark' then
        require("nvim-treesitter.configs").setup {
          rainbow = {
            enable = true,
            disable = { }, -- list of languages you want to disable the plugin for
            extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
            max_file_lines = nil, -- Do not enable for files with more than n lines, int
            colors = {'#79C0FF', '#56D364', '#FFA657', '#FA7970', '#FF9BCE', '#D2A8FF'}, -- table of hex strings
            -- termcolors = {} -- table of colour name strings
          }
        }
      else
        require("nvim-treesitter.configs").setup {
          rainbow = {
            enable = true,
            disable = { }, -- list of languages you want to disable the plugin for
            extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
            max_file_lines = nil, -- Do not enable for files with more than n lines, int
            colors = {'#0969DA', '#1A7F37', '#9A6700', '#CF222E', '#BF3989', '#8250DF'},
            -- termcolors = {} -- table of colour name strings
          }
        }
      end

    end
  }

  use {
    'windwp/nvim-ts-autotag',
    opt = true,
    config = function()
      require'nvim-treesitter.configs'.setup {
        autotag = {
          enable = true,
        }
      }
    end
  }

  use {
    'nvim-treesitter/nvim-treesitter-context',
    opt = true,
    config = function()
      require'treesitter-context'.setup {
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
      },
      mode = 'topline',
    }
    vim.cmd[[hi link TreesitterContext Context]]
  end
  }

  use {
    'm-demare/hlargs.nvim',
    opt = true,
    requires = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      if vim.g.colors_name == 'ghdark' then
        require('hlargs').setup {
          color = '#ef9062',
        }
      else
        require('hlargs').setup {
          color = '#E36209',
        }
      end
    end
  }

  -- cd to project root
  use {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup {
        silent_chdir = true,
        patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc", "pom.xml" },
        detection_methods = { "lsp", "pattern" },
        exclude_dirs = {'~'},
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
      vim.keymap.set('n', '<leader>v', '<cmd>AerialToggle!<CR>', { silent = true })
      local status_ok, telescope = pcall(require, "telescope")
      if status_ok then
        telescope.load_extension('aerial')
      end
      require("aerial").setup({
        backends = {
          _ = {"lsp", "treesitter", "markdown"},
        },
        filter_kind = {
          "Class",
          "Constructor",
          "Enum",
          "Function",
          "Interface",
          "Module",
          "Method",
          "Struct",
          "Namespace",
          "Field",
        },
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
        icons = {
          Namespace = " ",
        },
        max_width = 200,
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
      vim.o.winbar = " %#AerialWinHLFile#%{%v:lua.filename_with_icon()%} %#AerialWinHLFields#%{%v:lua.winbar_aerial()%}"

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
            opts = vim.tbl_extend('force', {silent = true}, opts or {})
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
    'NvChad/nvim-colorizer.lua',
    config = function()
      require'colorizer'.setup()
    end
  }

  use {
    'akinsho/bufferline.nvim',
    config = function()
      require("bufferline").setup {
        options = {
          separator_style = "slant",
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
      -- lsp info, from https://github.com/nvim-lualine/lualine.nvim/blob/master/examples/evil_lualine.lua
      local lsp_info =  {
        -- Lsp server name .
        function()
          local no_lsp = ''
          local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
          local clients = vim.lsp.get_active_clients()
          if next(clients) == nil then
            return no_lsp
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
            return no_lsp
          end
        end,
        icon = ' ',
        color = {gui = 'bold'}
      }

      vim.api.nvim_create_autocmd({"InsertEnter"}, {
        pattern = '*',
        callback = function()
          vim.g.wait_init = 1
        end,
        once = true
      })

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
            return "Tags Indexing..."
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

      local function void()
        return ' '
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
          lualine_c = {lsp_info, gtagsHandler},
          lualine_x = {auto_session_name()},
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
    opt = true,
    keys = "<leader>ra",
    config = function()
      vim.keymap.set('n', '<leader>ra', '<cmd>RnvimrToggle<CR>', {silent = true})
      vim.g.rnvimr_enable_picker = 1
    end
  }

  -- highlight cursor words via lsp
  use {
    'RRethy/vim-illuminate',
    config = function()
      vim.g.Illuminate_delay = 300
      vim.g.Illuminate_ftblacklist = {"NvimTree", "alpha", "dapui_scopes", "dapui_breakpoints", "help"}

      function highlightIlluminate()
        vim.cmd [[ hi link LspReferenceText UnderCursor ]]
        vim.cmd [[ hi link LspReferenceWrite UnderCursor ]]
        vim.cmd [[ hi link LspReferenceRead UnderCursor ]]
        vim.cmd [[ hi link illuminatedWord UnderCursor ]]
      end
      vim.defer_fn(highlightIlluminate, 0)
    end
  }

  use {
    'kyazdani42/nvim-tree.lua',
    requires = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icon
    },
    config = function()
      vim.keymap.set('n', '<leader>n', '<cmd>NvimTreeFindFileToggle<CR>', {silent = true})
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
        },
        renderer = {
          highlight_git = true,
          group_empty = true,
        }
      }
    end
  }

  use {
    'famiu/bufdelete.nvim',
    opt = true,
    keys = '<leader>x',
    config = function()
      vim.keymap.set('n', '<leader>x', '<cmd>Bdelete!<CR>', {silent = true})
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

  use {'MattesGroeger/vim-bookmarks', opt = true}
  use {
    'tom-anders/telescope-vim-bookmarks.nvim',
    config = function()
      require('telescope').load_extension('vim_bookmarks')
    end
  }

  use {
    'rmagatti/auto-session',
    config = function()
      require('auto-session').setup {
        log_level = 'error',
        auto_session_suppress_dirs = {'~/'},
        auto_session_create_enabled = false,
        auto_session_enable_last_session = true,
        auto_restore_enabled = false,
        post_restore_cmds = {'silent !kill -s SIGWINCH $PPID'},
        pre_save_cmds = {"NvimTreeClose"},
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
    opt = true,
    config = function()
      local function map(mode, lhs, rhs)
        vim.keymap.set(mode, lhs, rhs, { silent = true })
      end
      map('n', '<C-/>', '<CMD>lua require("Comment.api").toggle_current_linewise()<CR>')
      map('n', '<C-_>', '<CMD>lua require("Comment.api").toggle_current_linewise()<CR>')
      map('n', '<C-M-/>', '<CMD>lua require("Comment.api").toggle_current_blockwise()<CR>')
      map('n', '<C-M-_>', '<CMD>lua require("Comment.api").toggle_current_blockwise()<CR>')

      -- Linewise toggle using C-/
      map('x', '<C-/>', '<ESC><CMD>lua require("Comment.api").toggle_linewise_op(vim.fn.visualmode())<CR>')
      map('x', '<C-_>', '<ESC><CMD>lua require("Comment.api").toggle_linewise_op(vim.fn.visualmode())<CR>')

      -- Blockwise toggle using <leader>gb
      map('x', '<c-m-/>', '<ESC><CMD>lua require("Comment.api").toggle_blockwise_op(vim.fn.visualmode())<CR>')
      map('x', '<c-m-_>', '<ESC><CMD>lua require("Comment.api").toggle_blockwise_op(vim.fn.visualmode())<CR>')
    end
  }

  use {
    "bellini666/trouble.nvim",
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
      vim.keymap.set('n', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      vim.keymap.set('v', '<leader>w', "<cmd>lua require'hop'.hint_words()<cr>", {})
      -- vim.keymap.set('n', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
      -- vim.keymap.set('v', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
      vim.keymap.set('n', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
      vim.keymap.set('v', '<leader>l', "<cmd>lua require'hop'.hint_lines()<cr>", {})
    end
  }
  use {
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
  }

  use {
    'dstein64/nvim-scrollview',
    opt = true,
    config = function()
      vim.g.scrollview_current_only = 1
      vim.g.scrollview_excluded_filetypes = {"NvimTree", "alpha", "dapui_scopes"}
    end
  }

  use {
    'h-hg/fcitx.nvim',
    opt = false,
  }

  use {
    "folke/todo-comments.nvim",
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require("todo-comments").setup {
        -- your configuration comes here
      }
    end
  }

  use {
    "rcarriga/nvim-notify",
    config = function()
      vim.notify = require("notify")
    end
  }

  use {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = function()
      require("lsp_lines").setup()
    end,
  }

  use {
    -- enable yank through ssh
    'ojroques/nvim-osc52',
    opt = true,
  }

  -- vim plugins
  use {
    -- auto adjust indent length and format (tab or space)
    "tpope/vim-sleuth",
    opt = false
  }

  use {
    'neoclide/coc.nvim',
    opt = true,
    run = 'yarn install --frozen-lockfile',
    config = function()
      vim.keymap.set('n', '<leader><leader>', '<cmd>CocCommand<cr>', { silent = true })
    end
  }

  use {'junegunn/vim-easy-align', opt = true, cmd = "EasyAlign"}
  use {"dstein64/vim-startuptime", opt = false}
  use {
    'voldikss/vim-translator',
    opt = true,
    keys = "<leader>y",
    config = function()
      vim.keymap.set('n', '<leader>y', "<Plug>TranslateW", { silent = true })
      vim.keymap.set('v', '<leader>y', "<Plug>TranslateWV", { silent = true })
    end
  }
  use {
    'luochen1990/rainbow',
    opt = true,
    config = function()
      -- same as vim rainbow
      vim.g.rainbow_active = 1
      vim.g.rainbow_conf = {
        guifgs = {'#FF0000', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#FF00FF'}, -- table of hex strings
      }
    end
  }
  use {
    'iamcco/markdown-preview.nvim',
    opt = true,
    run = function() vim.fn["mkdp#util#install"]() end,
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
    opt = true,
    keys = "<leader>h",
    config = function()
      vim.keymap.set('n', '<leader>h', "<cmd>call InterestingWords('n')<cr>", { silent = true })
      vim.keymap.set('v', '<leader>h', "<cmd>call InterestingWords('v')<cr>", { silent = true })
      vim.keymap.set('n', '<leader>H', "<cmd>call UncolorAllWords()<cr>", { silent = true })
    end
  }
  use {'pgilad/vim-skeletons', opt = true }
  use {
    'SirVer/ultisnips',
    opt = true,
    requires = {{'honza/vim-snippets', rtp = '.'}},
    config = function()
      vim.g.UltiSnipsExpandTrigger = '<Plug>(ultisnips_expand)'
      vim.g.UltiSnipsJumpForwardTrigger = '<Plug>(ultisnips_jump_forward)'
      vim.g.UltiSnipsJumpBackwardTrigger = '<Plug>(ultisnips_jump_backward)'
      vim.g.UltiSnipsListSnippets = '<c-x><c-s>'
      vim.g.UltiSnipsRemoveSelectModeMappings = 0
      vim.g.UltiSnipsEditSplit="vertical"
      vim.g.UltiSnipsSnippetDirectories={ os.getenv("HOME") .. '/.vim/UltiSnips', "UltiSnips"}
      vim.g.UltiSnipsSnippetStorageDirectoryForUltiSnipsEdit = os.getenv("HOME") .. '/.vim/UltiSnips'
      vim.keymap.set('n', '<leader>ss', '<cmd>UltiSnipsEdit<cr>', { silent = true })
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "*.snippets",
        callback = function()
          vim.bo.filetype = "snippets"
        end
      })
    end
  }

  use {
    'github/copilot.vim',
    opt = true,
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
  }

  use {
    "lambdalisue/suda.vim",
    opt = false,
  }
  use {
    'mbbill/undotree',
    opt = false,
    config = function()
      vim.keymap.set('n', 'U', '<cmd>UndotreeToggle<cr>', { silent = true })
    end
  }
  use {
    'machakann/vim-sandwich',
    opt = true,
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

  use {'MTDL9/vim-log-highlighting', opt = true}

  use {
    'GustavoKatel/telescope-asynctasks.nvim',
    opt = true,
    keys = {"<leader>at", "<leader>ae"},
    cmd = "AsyncTaskTelescope",
    config = function()
      require('packer').loader('asynctasks.vim', 'asyncrun.vim', '<bang>' == '!')
      -- Fuzzy find over current tasks
      vim.cmd[[command! AsyncTaskTelescope lua require("telescope").extensions.asynctasks.all()]]
      vim.keymap.set('n', '<leader>at', '<cmd>AsyncTaskTelescope<cr>', { silent = true })
    end
  }


  use {
    'skywind3000/asynctasks.vim',
    opt = true,
    requires = {{'skywind3000/asyncrun.vim'}},
    config = function()
      vim.g.asyncrun_open = 6
      vim.g.asynctasks_term_pos = 'bottom'
      vim.g.asynctasks_term_rows = 14
      vim.keymap.set('n', '<leader>ae', '<cmd>AsyncTaskEdit<cr>', { silent = true })
    end
  }

  use {'skywind3000/asyncrun.vim', opt = true}

  use {
    'KabbAmine/vCoolor.vim',
    opt = true,
    keys = "<leader>cp",
    config = function()
      vim.g.vcoolor_disable_mappings = 1
      vim.keymap.set('n', '<leader>cp', '<cmd>VCoolor<cr>', { silent = true })
    end
  }

  use {
    'tpope/vim-fugitive',
    opt = true,
    cmd = {"G", "Gclog"}
  }

  use {
    'rbong/vim-flog',
    opt = true,
    cmd = {"Flog"},
    config = function()
      require('packer').loader('vim-fugitive', '<bang>' == '!')
    end
  }

  use {
    'mg979/vim-visual-multi',
    opt = true,
    config = function()
      vim.g.VM_theme = 'neon'
    end
  }

 --管理gtags，集中存放tags
  use {'ludovicchabant/vim-gutentags', opt = true, }
  use {
    'skywind3000/gutentags_plus',
    opt = true,
    config = function()
      -- enable gtags module
      -- vim.g.gutentags_modules = {'ctags', 'gtags_cscope'}
      vim.g.gutentags_modules = {'gtags_cscope'}

      -- config project root markers.
      vim.g.gutentags_project_root = {'.root', '.svn', '.git', '.hg', '.project', '.exrc', "pom.xml"}

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

      -- vim.keymap.set('n', '<F2>', '<Cmd>lua require"dap".terminate({},{terminateDebuggee=true},term_dap())<CR><Cmd>lua require"dap".close()<CR>', { silent = true })
      vim.keymap.set('n', '<F2>', '<Cmd>lua require"dap".terminate({},{terminateDebuggee=true},term_dap())<CR>', { silent = true })
      vim.keymap.set('n', '<F5>', '<Cmd>lua require"dap".continue()<CR>', { silent = true })
      vim.keymap.set('n', '<leader><F5>', '<Cmd>lua require"dap".run_to_cursor()<CR>', { silent = true })
      vim.keymap.set('n', '<F6>', '<Cmd>lua require"dap".pause()<CR>', { silent = true })
      vim.keymap.set('n', '<F6>',  '<Cmd>lua require"dap".pause()<CR>' , { silent = true })
      vim.keymap.set('n', '<F10>', '<Cmd>lua require"dap".step_over()<CR>' , { silent = true })
      vim.keymap.set('n', '<F11>', '<Cmd>lua require"dap".step_into()<CR>' , { silent = true })
      vim.keymap.set('n', '<F12>', '<Cmd>lua require"dap".step_out()<CR>' , { silent = true })
      vim.keymap.set('n', '<F9>',  '<Cmd>lua require"dap".toggle_breakpoint()<CR>' , { silent = true })
      vim.keymap.set('n', '<leader><F9>', '<Cmd>lua require"dap".clear_breakpoints()<CR>' , { silent = true })
      vim.keymap.set('n', '<F7>', '<Cmd>lua require("dapui").eval()<CR>' , { silent = true })
      vim.keymap.set('v', '<F7>', '<Cmd>lua require("dapui").eval()<CR>' , { silent = true })

      -- C/C++
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = vim.fn.stdpath('data') .. '/mason/bin/OpenDebugAD7',
      }


      --[[ dap.adapters.codelldb = function(callback, config)
      -- specify in your configuration host = your_host , port = your_port
      callback({ type = "server", host = config.host, port = config.port })
      end ]]

      local dap = require('dap')
      dap.adapters.lldb = {
        type = 'server',
        port = "${port}",
        executable = {
          -- CHANGE THIS to your path!
          command = vim.fn.stdpath('data') .. '/mason/bin/codelldb',
          args = {"--port", "${port}"},

          -- On windows you may have to uncomment this:
          -- detached = false,
        }
      }

      dap.configurations.cpp = {
        {
          name = "Launch file",
          -- type = "cppdbg",
          type = "lldb",
          request = "launch",
          -- stopOnEntry = true,
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
          -- type = "lldb",
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
        command = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python',
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
          -- modulePaths = {},
          name = "Launch Java Debug",
          request = "launch",
          type = "java"
        },
      }

      -- Dap load launch.json from vscode when avaliable
      if vim.fn.filereadable("./.vscode/launch.json") and vim.g.load_launchjs ~= 1 then
        require('dap.ext.vscode').load_launchjs(nil, { cppdbg = {'c', 'cpp', 'asm'} })
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

end,
config = {
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

  if vim.b.treesitter_disable ~= 1 then
    require('packer').loader(
    -- begin treesitter (slow performance)
    'nvim-ts-rainbow',   -- performance issue
    'nvim-treesitter-context',
    'nvim-treesitter-textobjects',
    'nvim-ts-autotag',
    'hlargs.nvim',
    -- end treesitter
    '<bang>' == '!')
  else
    require('packer').loader(
    'rainbow',
    '<bang>' == '!')
    vim.schedule(function()
      vim.fn["rainbow_main#load"]()
    end)
  end

  require('packer').loader(

  -- begin vim plugins
  'indent-blankline.nvim',
  'ultisnips',
  'cmp-nvim-ultisnips',
  'copilot.vim',
  'vim-sandwich',
  'vim-log-highlighting',
  'vim-visual-multi',
  'vim-bookmarks',
  'coc.nvim',
  -- end vim plugins

  -- begin misc
  'nvim-hlslens',
  'nvim-scrollview',
  'Comment.nvim',
  -- end misc

  '<bang>' == '!')

  -- autocmd TODO: Need to be fixed
  vim.api.nvim_exec("doautocmd User PluginsLoaded", true)
end

function loadTags()
  require('packer').loader('vim-gutentags gutentags_plus', '<bang>' == '!')
  vim.cmd("edit %")
end
vim.cmd("command! LoadTags lua loadTags()")

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
-- same as coc.nvim
vim.g.coc_config_home=vim.fn.glob(vim.fn.stdpath('data'))


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

-- vim.g.suda_smart_edit = 1

require("autosave").setup({
  enabled = true,
  execution_message = "",
  events = {"InsertLeave", "TextChanged"},
  conditions = {
    exists = true,
    filename_is_not = {},
    filetype_is_not = {},
    modifiable = true,
  },
  write_all_buffers = false,
  on_off_commands = false,
  clean_command_line_interval = 0,
  debounce_delay = 135
})

-- osc52 support on ssh
if os.getenv("SSH_CONNECTION") ~= nil then
  vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
      if have_load_osc52 == nil then
        have_load_osc52 = 1
        vim.cmd [[ packadd nvim-osc52 ]]
      end
      if vim.v.event.operator == 'y' and vim.v.event.regname == '' then
        require('osc52').copy_register('"')
      end
    end
  })
  -- vim.g.oscyank_term = 'default'
end

--------------------------------------------------------------------------------------
if vim.fn.expand('%:t') == '.nvimrc.lua' then
  vim.keymap.set('n', '<leader>wq', '<cmd>source %<cr> <cmd>PackerCompile<CR>', { silent = false })
  -- vim.cmd[[ au BufWritePost .nvimrc.lua source % | PackerCompile ]]
end
