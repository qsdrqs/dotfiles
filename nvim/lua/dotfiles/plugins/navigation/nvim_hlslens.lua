-- Plugin: kevinhwang91/nvim-hlslens
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

  }
end
