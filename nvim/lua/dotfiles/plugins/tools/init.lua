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
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      cond = vim.g.vscode == nil,
      opts = {},
    },

    {
      "willothy/flatten.nvim",
      lazy = false,
      config = function()
        local saved_terminal
        require("flatten").setup({
          window = {
            open = "alternate",
          },
          hooks = {
            pre_open = function()
              local term = require("toggleterm.terminal")
              local termid = term.get_focused_id()
              saved_terminal = term.get(termid)
            end,
            post_open = function(bufnr, winnr, ft, is_blocking)
              if saved_terminal then
                saved_terminal:shutdown()
              end
            end,
          },
        })
      end,
    },

    {
      "akinsho/toggleterm.nvim",
      keys = {
        "<localleader>t",
        "<C-`>",
        { "<C-Space>", mode = "n" },
        "<localleader>T",
      },
      cmd = {
        "ZjumpToggle",
      },
      config = function()
        require("toggleterm").setup({
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
          },
        })
        vim.keymap.set("n", "<localleader>t", "<cmd>exe v:count1 . 'ToggleTerm direction=vertical'<cr>")
        vim.keymap.set({ "n", "t" }, "<C-Space>", "<cmd>exe v:count1 . 'ToggleTerm'<cr>")

        -- lazy git
        local Terminal = require("toggleterm.terminal").Terminal

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
            vim.fn.setenv("EDITOR", "echo")
            tmp_file = vim.fn.tempname()
            cmd = "QUIT_ON_OPEN=1 yazi $CURR_FILE 1>" .. tmp_file
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
                        require("auto-session").restore_session()
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

        vim.api.nvim_create_user_command("ZjumpToggle", zjump_toggle, { nargs = 0 })

        vim.keymap.set("n", "<c-g>", lazygit_toggle, { noremap = true, silent = true })

        vim.api.nvim_create_user_command("YaziToggleOrig", yazi_toggle, { nargs = 0 })
        -- vim.keymap.set("n", "<leader>ya", yazi_toggle, {noremap = true, silent = true})

        -- repl
        vim.keymap.set("n", "<c-c><c-c>", "<cmd>ToggleTermSendCurrentLine<cr>")
        vim.keymap.set("v", "<c-c><c-c>", "<cmd>'<,'>ToggleTermSendVisualLines<cr>")
      end,
    },

    {
      "direnv/direnv.vim",
      lazy = true,
      init = function()
        vim.g.direnv_silent_load = 1
      end,
    },

    {
      -- permanent undo file
      "kevinhwang91/nvim-fundo",
      dependencies = { "kevinhwang91/promise-async" },
      keys = { "u", "<C-r>" },
      cond = vim.g.vscode == nil,
      build = function()
        require("fundo").install()
      end,
    },

    {
      "machakann/vim-sandwich",
      lazy = true,
      init = function()
        vim.g.sandwich_no_default_key_mappings = 1
      end,
      config = function()
        vim.cmd([[
        runtime macros/sandwich/keymap/surround.vim

        xmap is <Plug>(textobj-sandwich-query-i)
        xmap as <Plug>(textobj-sandwich-query-a)
        omap is <Plug>(textobj-sandwich-query-i)
        omap as <Plug>(textobj-sandwich-query-a)

        xmap iss <Plug>(textobj-sandwich-auto-i)
        xmap ass <Plug>(textobj-sandwich-auto-a)
        omap iss <Plug>(textobj-sandwich-auto-i)
        omap ass <Plug>(textobj-sandwich-auto-a)
        ]])
      end,
    },

    { "MTDL9/vim-log-highlighting", lazy = true },

    {
      "GustavoKatel/telescope-asynctasks.nvim",
      lazy = true,
      keys = { "<localleader>at", "<leader>ae" },
      cmd = "AsyncTaskTelescope",
      config = function()
        load_plugins({ "asynctasks.vim", "asyncrun.vim" })
        -- Fuzzy find over current tasks
        vim.cmd([[command! AsyncTaskTelescope lua require("telescope").extensions.asynctasks.all()]])
        vim.keymap.set("n", "<leader>at", "<cmd>AsyncTaskTelescope<cr>", { silent = true })
      end,
    },

    {
      "skywind3000/asynctasks.vim",
      lazy = true,
      dependencies = { "skywind3000/asyncrun.vim" },
      config = function()
        vim.g.asyncrun_open = 6
        vim.g.asynctasks_term_pos = "bottom"
        vim.g.asynctasks_term_rows = 14
        vim.keymap.set("n", "<leader>ae", "<cmd>AsyncTaskEdit<cr>", { silent = true })
      end,
    },

    { "skywind3000/asyncrun.vim", lazy = true },

    {
      "KabbAmine/vCoolor.vim",
      lazy = true,
      keys = "<leader>cp",
      init = function()
        vim.g.vcoolor_disable_mappings = 1
      end,
      config = function()
        vim.g.vcoolor_disable_mappings = 1
        vim.keymap.set("n", "<leader>cp", "<cmd>VCoolor<cr>", { silent = true })
      end,
    },

    {
      "famiu/bufdelete.nvim",
      lazy = true,
      keys = "<leader>x",
      cond = vim.g.vscode == nil,
      config = function()
        vim.keymap.set("n", "<leader>x", "<cmd>Bdelete!<CR>", { silent = true })
      end,
    },

    {
      "mg979/vim-visual-multi",
      lazy = true,
      keys = { { "<C-n>", mode = { "n", "v", "x" } } },
      config = function()
        vim.g.VM_theme = "neon"
      end,
    },

    {
      "lambdalisue/suda.vim",
      cmd = { "SudaRead", "SudaWrite" },
    },

    {
      "mbbill/undotree",
      keys = "U",
      config = function()
        vim.keymap.set("n", "U", "<cmd>UndotreeToggle<cr>", { silent = true })
      end,
    },

    {
      "Vonr/align.nvim",
      lazy = true,
      keys = { { "al", mode = "x" } },
      cmd = "Align",
      config = function()
        local NS = { noremap = true, silent = true }
        vim.keymap.set("x", "al", function()
          require("align").align_to_string({ preview = true, regex = true })
        end, NS)
        vim.api.nvim_create_user_command("Align", function(opts)
          _, sr, sc, _ = unpack(vim.fn.getpos("v") or { 0, 0, 0, 0 })
          _, er, ec, _ = unpack(vim.fn.getcurpos())
          require("align").align(opts.args, {
            preview = true,
            regex = true,
            marks = { sr = opts.line1, sc = sc, er = opts.line2, ec = ec },
          })
        end, { nargs = 1, range = true })
      end,
    },

    {
      -- enhanced <c-a> and <c-x>
      "monaqa/dial.nvim",
      keys = {
        { "g<C-a>", mode = "v" },
        { "g<C-x>", mode = "v" },
        { "<C-a>" },
        { "<C-x>" },
      },
      config = function()
        vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), { noremap = true })
        vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), { noremap = true })
        vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), { noremap = true })
        vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), { noremap = true })
        vim.keymap.set("v", "g<C-a>", require("dial.map").inc_gvisual(), { noremap = true })
        vim.keymap.set("v", "g<C-x>", require("dial.map").dec_gvisual(), { noremap = true })

        local augend = require("dial.augend")
        require("dial.config").augends:register_group({
          -- default augends used when no group name is specified
          default = {
            augend.integer.alias.decimal_int, -- nonnegative decimal number (0, 1, 2, 3, ...)
            augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
            augend.integer.alias.binary,
            augend.integer.alias.octal,
            augend.constant.alias.bool,
            augend.constant.new({
              elements = { "True", "False" },
            }),
            augend.constant.new({
              elements = { "yes", "no" },
            }),
            augend.semver.alias.semver,
            augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
          },
        })
      end,
    },

    {
      "numToStr/Comment.nvim",
      keys = {
        { "<c-_>", mode = "v" },
        { "<c-s-_>", mode = "v" },
        { "<c-_>", mode = "n" },
        { "<c-s-_>", mode = "n" },
        { "<c-/>", mode = "v" },
        { "<c-s-/>", mode = "v" },
        { "<c-/>", mode = "n" },
        { "<c-s-/>", mode = "n" },
      },
      cond = vim.g.vscode == nil,
      config = function()
        local bindkey
        if os.getenv("TMUX") ~= nil and vim.g.neovide == nil then
          bindkey = {
            line = "<c-_>",
            block = "<c-s-_>",
          }
        else
          bindkey = {
            line = "<c-/>",
            block = "<c-s-/>",
          }
        end
        require("Comment").setup({
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
                vim.cmd([[ normal gv ]])
              else
                vim.cmd([[ normal gvh ]])
              end
            end
          end,
        })

        local api = require("Comment.api")
        vim.api.nvim_create_user_command("ToggleComment", api.toggle.linewise.current, { nargs = 0 })
        vim.api.nvim_create_user_command("ToggleBlockComment", api.toggle.blockwise.current, { nargs = 0 })
      end,
    },

    {
      "kevinhwang91/rnvimr",
      lazy = true,
      cond = vim.g.vscode == nil,
      keys = "<leader>ra",
      cmd = "RnvimrToggle",
      config = function()
        vim.keymap.set("n", "<leader>ra", "<cmd>RnvimrToggle<CR>", { silent = true })
        vim.g.rnvimr_enable_picker = 1
      end,
    },

    {
      "mikavilpas/yazi.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      keys = {
        {
          "<leader>ya",
          function()
            require("yazi").yazi()
          end,
          { desc = "Open the yazi file manager" },
        },
      },
      cmd = {
        "YaziToggle",
      },
      config = function()
        if vim.fn.hlexists("FloatBorderClear") == 0 then
          vim.api.nvim_set_hl(0, "FloatBorderClear", { link = "FloatBorder" })
        end
        require("yazi").setup({
          floating_window_scaling_factor = 0.7,
          yazi_floating_window_border = {
            { "╭", "FloatBorderClear" },
            { "─", "FloatBorderClear" },
            { "╮", "FloatBorderClear" },
            { "│", "FloatBorderClear" },
            { "╯", "FloatBorderClear" },
            { "─", "FloatBorderClear" },
            { "╰", "FloatBorderClear" },
            { "│", "FloatBorderClear" },
          },
        })
        vim.api.nvim_create_user_command("YaziToggle", function()
          require("yazi").yazi()
        end, { nargs = 0 })
      end,
    },

    {
      "kana/vim-textobj-entire",
      keys = { "vie" },
      dependencies = { "kana/vim-textobj-user" },
    },
  }

  return specs
end

return M
