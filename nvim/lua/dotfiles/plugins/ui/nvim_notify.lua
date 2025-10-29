-- Plugin: rcarriga/nvim-notify
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
      "rcarriga/nvim-notify",
      init = function()
        local banned_messages = {
          "method textDocument/codeLens is not supported by any of the servers registered for the current buffer",
          "method textDocument/inlayHint is not supported by any of the servers registered for the current buffer",
          "[inlay_hints] LSP error:Invalid offset",
          "LSP[rust_analyzer] rust-analyzer failed to load workspace: Failed to read Cargo metadata from Cargo.toml",
          "position_encoding param is required",
          "warning: multiple different client offset_encodings detected for buffer",
          "The language server is either not installed, missing from PATH, or not executable.",
        }

        vim.notify = function(msg, ...)
          for _, banned in ipairs(banned_messages) do
            if string.find(msg, banned, 1, true) then
              return
            end
          end
          if string.find(msg, "signatureHelp", 1, true) then
            print(msg)
            return
          end
          if string.find(msg, "auto-session ERROR: Error restoring session", 1, true) then
            vim.cmd("normal! zR")
            vim.notify("Auto session corrupted, restored the old", "info", { title = "Auto Session" })
            require("auto-session").save_session()
            return
          end
          local ok, notify = pcall(require, "notify")
          if ok then
            -- local stack_trace = debug.traceback()
            -- notify(msg .. "\n\n" .. stack_trace, ...)
            notify(msg, ...)
          end
        end
      end,
    },

  }
end
