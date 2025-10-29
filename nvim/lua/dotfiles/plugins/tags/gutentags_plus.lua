-- Plugin: skywind3000/gutentags_plus
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
      "skywind3000/gutentags_plus",
      init = function()
        vim.g.gutentags_plus_nomap = 1
      end,
      lazy = true,
      config = function()
        vim.cmd([[
          noremap <silent> <leader>cgs :GscopeFind s <C-R><C-W><cr>
          noremap <silent> <leader>cgg :GscopeFind g <C-R><C-W><cr>
          noremap <silent> <leader>cgc :GscopeFind c <C-R><C-W><cr>
          noremap <silent> <leader>cgt :GscopeFind t <C-R><C-W><cr>
          noremap <silent> <leader>cge :GscopeFind e <C-R><C-W><cr>
          noremap <silent> <leader>cgf :GscopeFind f <C-R>=expand("<cfile>")<cr><cr>
          noremap <silent> <leader>cgi :GscopeFind i <C-R>=expand("<cfile>")<cr><cr>
          noremap <silent> <leader>cgd :GscopeFind d <C-R><C-W><cr>
          noremap <silent> <leader>cga :GscopeFind a <C-R><C-W><cr>
          noremap <silent> <leader>cgz :GscopeFind z <C-R><C-W><cr>
        ]])
      end,
    },

  }
end
