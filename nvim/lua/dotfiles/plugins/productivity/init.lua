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
      "okuuva/auto-save.nvim",
      event = { "InsertLeave", "TextChanged", "WinLeave", "BufLeave" },
      cond = vim.g.vscode == nil,
      opts = {
        trigger_events = { -- See :h events
          immediate_save = { "BufLeave", "FocusLost", "VimLeave" }, -- vim events that trigger an immediate save
          defer_save = { "InsertLeave", "TextChanged" }, -- vim events that trigger a deferred save (saves after `debounce_delay`)
          cancel_deferred_save = { "InsertEnter" }, -- vim events that cancel a pending deferred save
        },
        condition = function(buf) -- for claude code
          -- Exclude claudecode diff buffers by buffer name patterns
          local bufname = vim.api.nvim_buf_get_name(buf)
          if bufname:match("%(proposed%)") or bufname:match("%(NEW FILE %- proposed%)") or bufname:match("%(New%)") then
            return false
          end

          -- Exclude by buffer variables (claudecode sets these)
          if
            vim.b[buf].claudecode_diff_tab_name
            or vim.b[buf].claudecode_diff_new_win
            or vim.b[buf].claudecode_diff_target_win
          then
            return false
          end

          -- Exclude by buffer type (claudecode diff buffers use "acwrite")
          local buftype = vim.fn.getbufvar(buf, "&buftype")
          if buftype == "acwrite" then
            return false
          end

          return true -- Safe to auto-save
        end,
      },
    },

    {
      "iamcco/markdown-preview.nvim",
      lazy = true,
      build = function()
        vim.fn["mkdp#util#install"]()
      end,
      cmd = { "MarkdownPreview", "MarkdownPreviewInstall" },
      config = function()
        vim.api.nvim_create_user_command("MarkdownPreview", "echo 'Not a markdown file!'", { nargs = 0 })
        vim.api.nvim_create_user_command("MarkdownPreviewInstall", function()
          vim.fn["mkdp#util#install"]()
        end, { nargs = 0 })
        vim.api.nvim_exec_autocmds("BufEnter", {
          group = "mkdp_init",
        })
        vim.g.mkdp_open_to_the_world = 1
        vim.g.mkdp_echo_preview_url = 1

        vim.cmd([[
        function! Mkdp_handler(url)
          exec "silent !firefox -new-window " . a:url
        endfunction
        ]])

        vim.g.mkdp_browserfunc = "Mkdp_handler"
      end,
    },

    {
      "lfv89/vim-interestingwords",
      lazy = true,
      keys = "<leader>h",
      init = function()
        vim.g.interestingWordsDefaultMappings = 0
        vim.g.interestingWordsGUIColors = { "#8CCBEA", "#A4E57E", "#FFDB72", "#FF7272", "#FFB3FF", "#9999FF" }
      end,
      config = function()
        vim.keymap.set("n", "<leader>h", "<cmd>call InterestingWords('n')<cr>", { silent = true })
        vim.keymap.set("v", "<leader>h", "<cmd>call InterestingWords('v')<cr>", { silent = true })
        vim.keymap.set("n", "<leader>H", "<cmd>call UncolorAllWords()<cr>", { silent = true })
      end,
    },

    {
      -- auto adjust indent length and format (tab or space)
      "tpope/vim-sleuth",
      lazy = false,
    },

    {
      "qsdrqs/pantran.nvim",
      cond = vim.g.vscode == nil,
      keys = { { "<leader>y", mode = { "n", "x" } } },
      config = function()
        local opts = { noremap = true, silent = true, expr = true }
        local pantran = require("pantran")
        vim.keymap.set("n", "<leader>y", pantran.motion_translate, opts)
        vim.keymap.set("n", "<leader>yy", function()
          return pantran.motion_translate() .. "_"
        end, opts)
        vim.keymap.set("x", "<leader>y", pantran.motion_translate, opts)

        require("pantran").setup({
          default_engine = "google",
          engines = {
            deepl = {
              default_target = "ZH",
              auth_key = "fb82d24e-df8e-e7f2-5db4-142818d50c12:fx",
            },
            google = {
              fallback = {
                default_target = "zh-CN",
              },
            },
          },
        })
      end,
    },

    {
      "linux-cultist/venv-selector.nvim",
      dependencies = { "neovim/nvim-lspconfig", "ibhagwan/fzf-lua", "mfussenegger/nvim-dap-python" },
      cmd = { "VenvSelect", "VenvSelectCached" },
      config = function()
        require("venv-selector").setup({
          -- Your options go here
          -- name = "venv",
          -- auto_refresh = false
        })
      end,
    },
  }

  return specs
end

return M
