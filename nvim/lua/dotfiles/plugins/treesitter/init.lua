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
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        if vim.g.treesitter_disable == true or vim.g.vscode then
          return
        end
        require("nvim-treesitter.configs").setup({
          -- One of "all", or a list of languages
          ensure_installed = { "c", "cpp", "java", "python", "javascript", "rust", "markdown" },

          -- Install languages synchronously (only applied to `ensure_installed`)
          sync_install = false,

          -- Automatically install missing parsers when entering buffer
          -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
          auto_install = true,

          -- List of parsers to ignore installing
          ignore_install = { "bash" },

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
            },
          },
          indent = {
            enable = false,
          },
        })
        -- matlab
        local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
        parser_config.matlab = {
          install_info = {
            url = "https://github.com/mstanciu552/tree-sitter-matlab.git",
            files = { "src/parser.c" },
            branch = "main",
          },
          filetype = "matlab", -- if filetype does not agrees with parser name
        }
      end,
    },

    {
      "nvim-treesitter/playground",
      lazy = true,
      cmd = { "TSPlaygroundToggle" },
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("nvim-treesitter.configs").setup({
          playground = {
            enable = true,
            disable = {},
            updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
            persist_queries = false, -- Whether the query persists across vim sessions
            keybindings = {
              toggle_query_editor = "o",
              toggle_hl_groups = "i",
              toggle_injected_languages = "t",
              toggle_anonymous_nodes = "a",
              toggle_language_display = "I",
              focus_language = "f",
              unfocus_language = "F",
              update = "R",
              goto_node = "<cr>",
              show_help = "?",
            },
          },
        })
      end,
    },

    {
      "nvim-treesitter/nvim-treesitter-textobjects",
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
        require("nvim-treesitter.configs").setup(opts)
      end,
    },

    {
      "nvim-treesitter/nvim-treesitter-context",
      -- commit = "4842abe5bd1a0dc8b67387cc187edbabc40925ba",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("treesitter-context").setup({
          enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
          throttle = true, -- Throttles plugin updates (may improve performance)
          max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
          patterns = {
            -- For all filetypes
            -- Note that setting an entry here replaces all other patterns for this entry.
            -- By setting the 'default' entry below, you can control which nodes you want to
            -- appear in the context window.
            default = {
              "class",
              "function",
              "method",
              "namespace",
              "struct",
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
          mode = "topline",
        })
        vim.cmd([[hi! link TreesitterContext Context]])
      end,
    },

    {
      "windwp/nvim-ts-autotag",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("nvim-treesitter.configs").setup({
          autotag = {
            enable = true,
          },
        })
      end,
    },

    {
      "m-demare/hlargs.nvim",
      lazy = true,
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("hlargs").setup()
      end,
    },

    {
      "HiPhish/rainbow-delimiters.nvim",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        require("rainbow-delimiters.setup")({
          strategy = {
            [""] = "rainbow-delimiters.strategy.global",
            vim = "rainbow-delimiters.strategy.local",
          },
          query = {
            [""] = "rainbow-delimiters",
            lua = "rainbow-blocks",
            latex = "rainbow-blocks",
          },
          highlight = highlight_group_list,
          blacklist = {},
        })
      end,
    },

    {
      "RRethy/vim-illuminate",
      lazy = true,
      config = function()
        require("illuminate").configure({
          -- providers: provider used to get references in the buffer, ordered by priority
          providers = {
            "lsp",
            -- 'treesitter', -- treesitter is too slow!
            "regex",
          },
          -- delay: delay in milliseconds
          delay = 100,
          -- filetype_overrides: filetype specific overrides.
          -- The keys are strings to represent the filetype while the values are tables that
          -- supports the same keys passed to .configure except for filetypes_denylist and filetypes_allowlist
          filetype_overrides = {},
          -- filetypes_denylist: filetypes to not illuminate, this overrides filetypes_allowlist
          filetypes_denylist = {
            "dirvish",
            "fugitive",
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

        vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "UnderCursorText" })
        vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "UnderCursorRead" })
        vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "UnderCursorWrite" })
      end,
    },

    {
      "andymass/vim-matchup",
      init = function()
        vim.g.matchup_matchparen_offscreen = { method = "" }
        vim.g.matchup_matchparen_deferred = 1
        vim.g.matchup_matchparen_hi_surround_always = 1
        vim.g.matchup_treesitter_disable_virtual_text = true
        vim.g.matchup_treesitter_enabled = true
      end,
      config = function()
        require("nvim-treesitter.configs").setup({
          matchup = {
            enable = true, -- mandatory, false will disable the whole extension
            disable_virtual_text = true,
            -- [options]
          },
        })
      end,
    },

    {
      "luochen1990/rainbow",
      lazy = true,
      config = function()
        -- same as vim rainbow
        vim.g.rainbow_active = 1
        vim.g.rainbow_conf = {
          guifgs = { "#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF" }, -- table of hex strings
        }
      end,
    },

    {
      -- smart fold
      "kevinhwang91/nvim-ufo",
      dependencies = { "kevinhwang91/promise-async" },
      config = function()
        if vim.b.treesitter_disable ~= 1 then
          load_plugin("nvim-treesitter")
        end

        vim.o.foldcolumn = "1"
        vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
        vim.o.foldlevelstart = 99
        vim.o.foldenable = true

        local function handler(virt_text, lnum, end_lnum, width, truncate, ctx)
          local result = {}

          local counts = ("󰁂 %d"):format(end_lnum - lnum)
          local prefix = "⋯⋯  "
          local suffix = "  ⋯⋯"
          local padding = ""

          local end_virt_text = ctx.get_fold_virt_text(end_lnum)
          -- trim the end_virt_text
          local leader_num = 0
          for i = 1, #end_virt_text[1][1] do
            local c = end_virt_text[1][1]:sub(i, i)
            if c == " " then
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
            if
              string.find(end_virt_text[1][1], "}", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "{", 1, true)
            then
              maybe_left_parenthesis = { " {", end_virt_text[1][2] }
            end
            if
              string.find(end_virt_text[1][1], "]", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "[", 1, true)
            then
              maybe_left_parenthesis = { " [", end_virt_text[1][2] }
            end
            if
              string.find(end_virt_text[1][1], ")", 1, true)
              and not string.find(start_virt_text[#start_virt_text][1], "(", 1, true)
            then
              maybe_left_parenthesis = { " (", end_virt_text[1][2] }
            end
          end

          if end_virt_text_width > 5 then
            end_virt_text = {}
            end_virt_text_width = 0
          end

          local sufWidth = (2 * vim.fn.strdisplaywidth(suffix)) + vim.fn.strdisplaywidth(counts) + end_virt_text_width

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
            if type(err) == "string" and err:match("UfoFallbackException") then
              return require("ufo").getFolds(providerName, bufnr)
            else
              return require("promise").reject(err)
            end
          end

          return require("ufo")
            .getFolds("lsp", bufnr)
            :catch(function(err)
              return handleFallbackException(err, "treesitter")
            end)
            :catch(function(err)
              return handleFallbackException(err, "indent")
            end)
        end

        require("ufo").setup({
          provider_selector = function(bufnr, filetype, buftype)
            return customizeSelector
          end,
          enable_get_fold_virt_text = true,
          fold_virt_text_handler = handler,
        })
        -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
        vim.keymap.set("n", "zR", require("ufo").openAllFolds)
        vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
      end,
    },

    { "kevinhwang91/promise-async" },

    {
      "Wansmer/treesj",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      keys = { { "<leader>j", mode = "n" } },
      config = function()
        require("treesj").setup({
          use_default_keymaps = false,
        })
        vim.keymap.set("n", "<leader>j", require("treesj").toggle, { silent = true })
      end,
    },

    {
      "lukas-reineke/indent-blankline.nvim",
      lazy = true,
      cond = function()
        return vim.g.treesitter_disable ~= true
      end,
      config = function()
        local ok, treesitter = pcall(require, "nvim-treesitter")
        if vim.b.treesitter_disable ~= 1 then
          vim.g.indent_blankline_show_current_context = true
          vim.g.indent_blankline_show_current_context_start = true
        end
        local hooks = require("ibl.hooks")
        require("ibl").setup({
          indent = {
            -- char = '▏',
            -- context_char = '▎',
          },
          debounce = 300,
          scope = {
            enabled = true,
            highlight = highlight_group_list,
            show_end = true,
          },
        })
        hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
      end,
    },
  }

  return specs
end

return M
