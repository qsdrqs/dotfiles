-- Plugin: mikavilpas/yazi.nvim
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
      "mikavilpas/yazi.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      keys = {
        {
          "<leader>ya",
          function()
            require("yazi").yazi()
          end,
          { desc = "Open the yazi file manager" },
        },
      },
      cmd = {
        "YaziToggle",
      },
      config = function()
        if vim.fn.hlexists("FloatBorderClear") == 0 then
          vim.api.nvim_set_hl(0, "FloatBorderClear", { link = "FloatBorder" })
        end
        require("yazi").setup({
          floating_window_scaling_factor = 0.7,
          yazi_floating_window_border = {
            { "╭", "FloatBorderClear" },
            { "─", "FloatBorderClear" },
            { "╮", "FloatBorderClear" },
            { "│", "FloatBorderClear" },
            { "╯", "FloatBorderClear" },
            { "─", "FloatBorderClear" },
            { "╰", "FloatBorderClear" },
            { "│", "FloatBorderClear" },
          },
        })
        vim.api.nvim_create_user_command("YaziToggle", function()
          require("yazi").yazi()
        end, { nargs = 0 })
      end,
    },

  }
end
