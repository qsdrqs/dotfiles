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
      "nvim-lua/plenary.nvim",
      cmd = {
        "PlenaryProfile",
        "PlenaryProfileStop",
      },
      config = function()
        vim.api.nvim_create_user_command("PlenaryProfile", function()
          require("plenary.profile").start("profile.log", { flame = true })
        end, { nargs = 0 })
        vim.api.nvim_create_user_command("PlenaryProfileStop", function()
          require("plenary.profile").stop()
        end, { nargs = 0 })
      end,
    },

    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      cond = vim.g.vscode == nil,
      config = function()
        local action_set = require("telescope.actions.set")

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
          return vim.api.nvim_feedkeys(t("7h"), "n", true)
        end
        local function move_right_7()
          return vim.api.nvim_feedkeys(t("7l"), "n", true)
        end

        local status_ok, trouble_telscope = pcall(require, "trouble.sources.telescope")
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
            },
          },
        }
        if status_ok then
          opts.defaults.mappings.i["<C-t>"] = trouble_telscope.open
          opts.defaults.mappings.n["<C-t>"] = trouble_telscope.open
        end
        require("telescope").setup(opts)
      end,
    },

    {
      "ibhagwan/fzf-lua",
      -- optional for icon support
      dependencies = { "nvim-tree/nvim-web-devicons" },
      cond = vim.g.vscode == nil,
      cmd = {
        "FzfLua",
      },
      keys = {
        "<leader>f",
        "<leader>b",
        "<leader>gs",
        "<leader>gg",
        "<leader>gG",
        "<leader>t",
        "<leader>rc",
        "<leader>rf",
        "<leader>rw",
        "<leader>rl",
        "<leader>rt",
      },
      -- or if using mini.icons/mini.nvim
      -- dependencies = { "echasnovski/mini.icons" },
      config = function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.setup({
          grep = {
            rg_glob = true,
            -- first returned string is the new search query
            -- second returned string are (optional) additional rg flags
            -- @return string, string?
            rg_glob_fn = function(query, opts)
              local regex, flags = query:match("^(.-)%s%-%-(.*)$")
              -- If no separator is detected will return the original query
              return (regex or query), flags
            end,
          },
          winopts = {
            preview = {
              default = "bat_native",
              horizontal = "right:55%",
            },
            width = 0.85,
          },
          keymap = {
            fzf = {
              true,
              -- Use <c-q> to select all items and add them to the quickfix list
              ["ctrl-q"] = "select-all+accept",
            },
          },
          fzf_opts = {
            ["--cycle"] = true,
          },
        })
        vim.keymap.set("n", "<leader>f", fzf_lua.files, { silent = true })
        vim.keymap.set("n", "<leader>F", function()
          fzf_lua.files({ no_ignore = true })
        end, { silent = true })
        vim.keymap.set("n", "<leader>b", fzf_lua.buffers, { silent = true })
        vim.keymap.set("n", "<leader>gs", fzf_lua.grep_cword, { silent = true })
        vim.keymap.set("v", "<leader>gs", fzf_lua.grep_visual, { silent = true })
        vim.keymap.set("n", "<leader>gg", fzf_lua.live_grep, { silent = false })
        vim.keymap.set("n", "<leader>gG", fzf_lua.live_grep_glob, { silent = true })
        vim.keymap.set("n", "<leader>t", fzf_lua.builtin, { silent = true })
        vim.keymap.set("n", "<leader>rc", fzf_lua.command_history, { silent = true })
        vim.keymap.set("n", "<leader>rf", fzf_lua.lsp_document_symbols, { silent = true })
        vim.keymap.set("n", "<leader>rw", fzf_lua.lsp_workspace_symbols, { silent = true })
        vim.keymap.set("n", "<leader>rl", fzf_lua.blines, { silent = true })
        vim.keymap.set("n", "<leader>rt", fzf_lua.treesitter, { silent = true })
      end,
    },

    { "seandewar/sigsegvim", cmd = "Sigsegv" },

    { "Eandrju/cellular-automaton.nvim", cmd = "CellularAutomaton" },

    {
      "kevinhwang91/nvim-bqf",
      config = function()
        vim.cmd([[
          hi BqfPreviewBorder guifg=#50a14f ctermfg=71
          hi link BqfPreviewRange Search
        ]])
        require("bqf").setup({
          auto_enable = true,
          auto_resize_height = false,
          preview = {
            win_height = 999, -- full screen
            win_vheight = 12,
            delay_syntax = 80,
            border_chars = { "┃", "┃", "━", "━", "┏", "┓", "┗", "┛", "█" },
            should_preview_cb = function(bufnr, qwinid)
              local ret = true
              local bufname = vim.api.nvim_buf_get_name(bufnr)
              local fsize = vim.fn.getfsize(bufname)
              if fsize > 100 * 1024 then
                -- skip file size greater than 100k
                ret = false
              elseif bufname:match("^fugitive://") then
                -- skip fugitive buffer
                ret = false
              end
              return ret
            end,
          },
          -- make `drop` and `tab drop` to become preferred
          func_map = {
            drop = "o",
            openc = "O",
            split = "<C-s>",
            tabdrop = "<C-t>",
            tabc = "",
            ptogglemode = "z,",
          },
          filter = {
            fzf = {
              action_for = { ["ctrl-s"] = "split", ["ctrl-t"] = "tab drop" },
              extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
            },
          },
        })
      end,
    },

    {
      "kevinhwang91/nvim-hlslens",
      lazy = true,
      config = function()
        local kopts = { silent = true }

        vim.keymap.set(
          "n",
          "n",
          [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
          kopts
        )
        vim.keymap.set(
          "n",
          "N",
          [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
          kopts
        )
        vim.keymap.set("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("n", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("n", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

        vim.keymap.set("x", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("x", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("x", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
        vim.keymap.set("x", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

        require("hlslens").setup({
          calm_down = false,
          nearest_only = true,
          nearest_float_when = "auto",
          build_position_cb = function(plist, _, _, _)
            require("scrollbar.handlers.search").handler.show(plist.start_pos)
          end,
        })
      end,
    },

    {
      "DrKJeff16/project.nvim",
      config = function()
        vim.g.project_lsp_nowarn = 1
        require("project").setup({
          silent_chdir = true,
          manual_mode = false,
          patterns = { ".git", ".hg", ".bzr", ".svn", ".root", ".project", ".exrc", "pom.xml" },
          detection_methods = { "pattern", "lsp" },
          ignore_lsp = { "clangd" },
          exclude_dirs = { "~" },
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        })

        require("telescope").load_extension("projects")
      end,
    },

    {
      "smoka7/hop.nvim",
      lazy = true,
      keys = {
        { "<leader>w", mode = { "n", "v" } },
        { "<leader>l", mode = { "n", "v" } },
      },
      config = function()
        require("hop").setup()
        vim.keymap.set("n", "<leader>w", "<cmd>lua require'hop'.hint_words()<cr>", {})
        vim.keymap.set("v", "<leader>w", "<cmd>lua require'hop'.hint_words()<cr>", {})
        -- vim.keymap.set('n', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
        -- vim.keymap.set('v', '<leader>e', "<cmd>lua require'hop'.hint_words({hint_position = require'hop.hint'.HintPosition.END})<cr>", {})
        vim.keymap.set("n", "<leader>l", "<cmd>lua require'hop'.hint_lines()<cr>", {})
        vim.keymap.set("v", "<leader>l", "<cmd>lua require'hop'.hint_lines()<cr>", {})
      end,
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
        require("flash").setup({
          modes = {
            search = {
              enabled = false,
            },
            char = {
              jump_labels = true,
              highlight = {
                backdrop = false,
              },
            },
          },
          label = {
            rainbow = {
              enabled = false,
            },
          },
        })
      end,
    },

    {
      "folke/which-key.nvim",
      config = function()
        require("which-key").setup({
          -- your configuration comes here
          -- or leave it empty to use the default settings
          plugins = {
            registers = false,
          },
          win = {
            border = "single",
            wo = {
              winblend = 10,
            },
          },
        })
      end,
    },

    {
      "chentoast/marks.nvim",
      event = "VeryLazy",
      opts = {},
    },

    {
      "tversteeg/registers.nvim",
      keys = {
        { '"', mode = { "v", "n" } },
        { "<C-r>", mode = { "i" } },
      },
      cond = vim.g.vscode == nil,
      opts = {
        window = {
          border = "single",
        },
      },
    },
  }

  return specs
end

return M
