-- Plugin: okuuva/auto-save.nvim
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

  }
end
