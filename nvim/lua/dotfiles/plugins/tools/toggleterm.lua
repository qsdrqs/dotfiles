-- Plugin: akinsho/toggleterm.nvim
return function(ctx)
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

  return {

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

  }
end
