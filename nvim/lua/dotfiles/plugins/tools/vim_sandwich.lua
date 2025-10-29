-- Plugin: machakann/vim-sandwich
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

  }
end
