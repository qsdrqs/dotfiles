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
      "rmagatti/auto-session",
      init = function()
        if #vim.fn.argv() == 1 and vim.fn.isdirectory(vim.fn.argv()[1]) == 1 then
          vim.cmd.cd(vim.fn.argv()[1])
          local res = require("auto-session").restore_session()
          -- if res then
          --   vim.cmd("bdelete " .. vim.fn.getcwd())
          -- end
        end
      end,
      config = function()
        if vim.g.neovide ~= nil and #vim.fn.argv() == 0 and vim.g.remote_ui == nil then
          vim.defer_fn(function() -- execute after function exit (setted up)
            local last_session = require("auto-session").get_latest_session()
            require("auto-session").restore_session(last_session)
          end, 0)
        end
        require("auto-session").setup({
          log_level = "error",
          auto_session_suppress_dirs = { "~/", "~/Downloads", "~/Documents" },
          auto_session_create_enabled = false,
          auto_session_enable_last_session = false,
          auto_save_enabled = true,
          auto_restore_enabled = true,
          post_restore_cmds = { "silent !kill -s SIGWINCH $PPID" },
          pre_restore = "let g:not_start_alpha = true",
          pre_save_cmds = {
            function()
              pcall(vim.cmd, "NvimTreeClose")
            end,
          },
        })
        vim.api.nvim_create_user_command("SessionClose", function()
          require("auto-session").save_session()
          vim.cmd("Alpha")
        end, { nargs = 0 })
      end,
    },
  }

  return specs
end

return M
