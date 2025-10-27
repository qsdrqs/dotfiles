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
      "lewis6991/gitsigns.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      config = function()
        require("gitsigns").setup({
          signs = {
            add = { text = "│" },
            change = { text = "│" },
            delete = { text = "_" },
            topdelete = { text = "‾" },
            changedelete = { text = "~" },
            untracked = { text = "┆" },
          },
          signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
          numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
          linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
          word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
          watch_gitdir = {
            interval = 1000,
            follow_files = true,
          },
          attach_to_untracked = true,
          current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
          current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
            virt_text_priority = 0,
            delay = 250,
            ignore_whitespace = false,
          },
          current_line_blame_formatter = "      <author>, <author_time:%R> - <summary>",
          sign_priority = 6,
          update_debounce = 100,
          status_formatter = nil, -- Use default
          max_file_length = 40000,
          preview_config = {
            -- Options passed to nvim_open_win
            border = "single",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1,
          },
          on_attach = function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation
            map("n", "]g", function()
              if vim.wo.diff then
                return "]c"
              end
              vim.schedule(function()
                if vim.g.vscode then
                  vscode_next_hunk()
                else
                  gs.next_hunk()
                end
              end)
              return "<Ignore>"
            end, { expr = true })

            map("n", "[g", function()
              if vim.wo.diff then
                return "[c"
              end
              vim.schedule(function()
                if vim.g.vscode then
                  vscode_prev_hunk()
                else
                  gs.prev_hunk()
                end
              end)
              return "<Ignore>"
            end, { expr = true })

            -- Actions
            map({ "n", "v" }, "<leader>ga", ":Gitsigns stage_hunk<CR>")
            map("n", "<leader>gA", gs.stage_buffer)
            map("n", "<leader>gu", gs.undo_stage_hunk)
            map({ "n", "v" }, "<leader>gr", ":Gitsigns reset_hunk<CR>")
            map("n", "<leader>gR", "<cmd>Gitsigns reset_buffer<CR>")
            map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>")
            map("n", "<leader>gm", '<cmd>lua require"gitsigns".blame_line{full=true}<CR>')
            map("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<CR>")
            map("n", "<leader>gd", "<cmd>Gitsigns toggle_deleted<CR>")

            -- Text object
            map("o", "ih", ":<C-U>Gitsigns select_hunk<CR>")
            map("x", "ih", ":<C-U>Gitsigns select_hunk<CR>")
          end,
        })
      end,
    },

    {
      -- NOTE: prefer to use diffview.nvim instead
      "akinsho/git-conflict.nvim",
      tag = "v2.1.0",
      config = function()
        require("git-conflict").setup({
          default_mappings = false,
        })
        vim.keymap.set("n", "]x", "<cmd>GitConflictNextConflict<cr>")
        vim.keymap.set("n", "[x", "<cmd>GitConflictPrevConflict<cr>")
      end,
    },

    {
      "sindrets/diffview.nvim",
      lazy = true,
      cmd = { "DiffviewOpen", "DiffviewFileHistory" },
      opts = {
        view = {
          merge_tool = {
            layout = "diff3_mixed",
          },
        },
      },
    },

    {
      "echasnovski/mini.diff",
      config = function()
        local diff = require("mini.diff")
        diff.setup({
          -- Disabled by default
          source = diff.gen_source.none(),
        })
      end,
    },

    {
      "tpope/vim-fugitive",
      lazy = true,
      cmd = { "G", "Gclog", "Gvdiffsplit" },
    },

    {
      "rbong/vim-flog",
      lazy = true,
      cmd = { "Flog" },
      dependencies = { "tpope/vim-fugitive" },
    },
  }

  return specs
end

return M
