-- Plugin: folke/flash.nvim
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
      "folke/flash.nvim",
      opts = {},
      -- stylua: ignore
      keys = {
        { "s", mode = { "n", "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
        { "<leader><CR>", mode = { "n", "o", "x" }, function() require("nvim-treesitter"); require("flash").treesitter() end, desc = "Flash Treesitter" },
        { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
        { "R", mode = { "o", "x" }, function() require("nvim-treesitter"); require("flash").treesitter_search() end, desc = "Treesitter Search" },
        { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
        { "f", "F", "t", "T"},
      },
      config = function()
        local hls = {
          -- FlashBackdrop = { fg = "#545c7e" },
          FlashCurrent = { bg = "#ff966c", fg = "#1b1d2b" },
          FlashLabel = { bg = "#ff007c", bold = true, fg = "#c8d3f5" },
          FlashMatch = { bg = "#3e68d7", fg = "#c8d3f5" },
        }
        for hl_group, hl in pairs(hls) do
          hl.default = true
          vim.api.nvim_set_hl(0, hl_group, hl)
        end
        require("flash").setup({
          modes = {
            search = {
              enabled = false,
            },
            char = {
              jump_labels = true,
              highlight = {
                backdrop = false,
              },
            },
          },
          label = {
            rainbow = {
              enabled = false,
            },
          },
        })
      end,
    },

  }
end
