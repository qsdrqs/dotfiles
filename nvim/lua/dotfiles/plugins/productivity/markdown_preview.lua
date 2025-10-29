-- Plugin: iamcco/markdown-preview.nvim
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

  }
end
