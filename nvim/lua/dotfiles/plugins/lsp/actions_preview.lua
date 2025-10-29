-- Plugin: aznhe21/actions-preview.nvim
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
      "aznhe21/actions-preview.nvim",
      dependencies = {
        "nvim-telescope/telescope.nvim",
      },
      keys = {
        { "<leader>ca", mode = { "v", "n" } },
      },
      config = function()
        require("actions-preview").setup({
          telescope = {
            sorting_strategy = "ascending",
            layout_strategy = "vertical",
            layout_config = {
              width = 0.8,
              height = 0.9,
              prompt_position = "top",
              preview_cutoff = 20,
              preview_height = function(_, _, max_lines)
                return max_lines - 15
              end,
            },
          },
        })
        vim.keymap.set({ "v", "n" }, "<leader>ca", require("actions-preview").code_actions)
      end,
    },

  }
end
