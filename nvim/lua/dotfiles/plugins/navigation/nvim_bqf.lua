-- Plugin: kevinhwang91/nvim-bqf
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

  }
end
